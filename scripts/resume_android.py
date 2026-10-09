"""Inspect or resume CiNey on a connected Android device using Python + ADB.

Only taps controls found in the current accessibility tree. No fixed screen
coordinates, desktop automation libraries, provider URLs or media extraction.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path


PACKAGES = {"com.ciney.app", "com.ciney.tv"}
UI_PATH = "/sdcard/ciney-resume-inspect.xml"


def label(node):
    return (node.get("text") or node.get("content-desc") or "").strip()


def bounds(node):
    numbers = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
    if not numbers:
        return None
    left, top, right, bottom = map(int, numbers.groups())
    return (left, top, right, bottom) if right > left and bottom > top else None


class AndroidResume:
    def __init__(self, adb, serial):
        self.adb = adb
        self.serial = serial

    def command(self, *args):
        result = subprocess.run(
            [self.adb, "-s", self.serial, *args],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
            timeout=25,
        )
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or result.stdout.strip())
        return result.stdout

    def foreground(self):
        activity = self.command("shell", "dumpsys", "activity", "activities")
        resumed = next((line for line in activity.splitlines() if "mResumedActivity:" in line), "")
        package = next((package for package in PACKAGES if f"{package}/" in resumed), None)
        if not package:
            raise RuntimeError("O CiNey precisa estar aberto em primeiro plano. Nenhum toque foi enviado.")
        return package

    def inspect(self):
        package = self.foreground()
        self.command("shell", "uiautomator", "dump", UI_PATH)
        tree = ET.fromstring(self.command("shell", "cat", UI_PATH).strip())
        return package, tree

    def tap(self, tree, node):
        parents = {child: parent for parent in tree.iter() for child in parent}
        target = node
        while target.get("clickable") != "true" and target in parents:
            target = parents[target]
        if target.get("clickable") != "true" and label(node) == "Servidor Principal":
            # DOM elements with delegated listeners are exposed as plain text by
            # Android accessibility. Only allow this known control inside WebView.
            ancestors = []
            ancestor = node
            while ancestor in parents:
                ancestor = parents[ancestor]
                ancestors.append(ancestor)
            audio_labels = {label(element) for element in tree.iter("node")}
            if any(element.get("class") == "android.webkit.WebView" for element in ancestors) and \
                    {"Dublado", "Legendado"}.issubset(audio_labels):
                target = node
        is_server = target is node and label(node) == "Servidor Principal"
        rectangle = bounds(target)
        if (target.get("clickable") != "true" and not is_server) or target.get("enabled") != "true" or not rectangle:
            raise RuntimeError("O controle encontrado não está disponível para toque.")
        self.foreground()
        left, top, right, bottom = rectangle
        self.command("shell", "input", "tap", str((left + right) // 2), str((top + bottom) // 2))
        print(json.dumps({"action": "tap", "label": label(node), "bounds": rectangle}, ensure_ascii=False), flush=True)

    def resume(self, title, wait_seconds):
        _, tree = self.inspect()
        if title:
            headers = [node for node in tree.iter("node") if label(node) == "Continuar Assistindo" and bounds(node)]
            if len(headers) != 1:
                raise RuntimeError("Abra a página inicial com Continuar Assistindo visível.")
            start = bounds(headers[0])[3]
            next_headers = [bounds(node)[1] for node in tree.iter("node")
                            if label(node) in {"Favoritos", "Lançamentos"} and bounds(node)
                            and bounds(node)[1] > start]
            end = min(next_headers) if next_headers else float("inf")
            cards = [node for node in tree.iter("node") if label(node) == title
                     and node.get("clickable") == "true" and bounds(node)
                     and start <= bounds(node)[1] < end]
            if len(cards) != 1:
                raise RuntimeError("O título precisa identificar um único cartão em Continuar Assistindo.")
            self.tap(tree, cards[0])
        deadline = time.monotonic() + wait_seconds
        while time.monotonic() < deadline:
            _, tree = self.inspect()
            servers = [node for node in tree.iter("node") if label(node) == "Servidor Principal" and bounds(node)]
            if len(servers) == 1:
                self.tap(tree, servers[0])
                print("Servidor selecionado por toque Android. A posição salva fica a cargo do player do app.", flush=True)
                return
            if len(servers) > 1:
                raise RuntimeError("Há mais de um Servidor Principal; nenhum toque automático foi enviado.")
            time.sleep(1)
        raise RuntimeError("O menu não foi encontrado no prazo. A reprodução não foi confirmada.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", help="Caminho do adb.exe, se não estiver no PATH.")
    parser.add_argument("--serial", help="Dispositivo mostrado por adb devices.")
    parser.add_argument("--resume", action="store_true", help="Enviar toque no servidor; sem esta opção, apenas inspeciona.")
    parser.add_argument("--title", help="Nome exato do cartão em Continuar Assistindo, incluindo temporada/episódio se exibidos.")
    parser.add_argument("--wait-seconds", type=int, default=30, choices=range(1, 61), metavar="1..60")
    args = parser.parse_args()
    if args.title and not args.resume:
        parser.error("--title exige --resume")
    candidate = Path(os.environ.get("LOCALAPPDATA", "")) / "Android/Sdk/platform-tools/adb.exe"
    adb = args.adb or shutil.which("adb") or (str(candidate) if candidate.is_file() else None)
    if not adb:
        parser.error("ADB não encontrado. Informe --adb.")
    if not args.serial:
        devices = subprocess.run([adb, "devices"], capture_output=True, text=True, check=True, timeout=15).stdout
        available = [line.split()[0] for line in devices.splitlines() if re.search(r"\sdevice$", line)]
        if len(available) != 1:
            parser.error("Conecte um dispositivo ou informe --serial para selecionar um único Android.")
        args.serial = available[0]
    runner = AndroidResume(adb, args.serial)
    try:
        if args.resume:
            runner.resume(args.title, args.wait_seconds)
        else:
            package, tree = runner.inspect()
            version = runner.command("shell", "dumpsys", "package", package)
            versions = re.findall(r"version(?:Name|Code)=[^\s]+", version)
            controls = [{"label": label(node), "id": node.get("resource-id"),
                         "class": node.get("class"), "clickable": node.get("clickable"),
                         "bounds": node.get("bounds")}
                        for node in tree.iter("node") if label(node) or node.get("resource-id")]
            print(json.dumps({"package": package, "version": versions, "controls": controls}, ensure_ascii=False, indent=2))
    except (RuntimeError, subprocess.SubprocessError, ET.ParseError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
