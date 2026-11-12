#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");

if (process.platform !== "win32") {
  console.error("[bim-mode-mcp] BIM-MODE Connector requires Windows (Autodesk Revit / AutoCAD / Navisworks).");
  process.exit(1);
}

const args = process.argv.slice(2);

if (args[0] === "--install") {
  const installer = path.resolve(__dirname, "..", "gitinstall.ps1");
  if (!fs.existsSync(installer)) {
    console.error("[bim-mode-mcp] gitinstall.ps1 not found at: " + installer);
    process.exit(1);
  }
  const psArgs = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", installer];
  if (args[1] && /^\d{4}$/.test(args[1])) {
    psArgs.push("-RevitVersion", args[1]);
  }
  const child = spawn("powershell.exe", psArgs, { stdio: "inherit" });
  child.on("exit", (code) => process.exit(code ?? 1));
  child.on("error", (err) => {
    console.error("[bim-mode-mcp] Failed to start PowerShell: " + err.message);
    process.exit(1);
  });
} else {
  function findBridgeExe() {
    const localAppData = process.env.LOCALAPPDATA || "";
    const appData = process.env.APPDATA || "";
    const candidates = [];

    if (localAppData) {
      candidates.push(path.join(localAppData, "BIM-MODE", "bridge", "BimMode.Bridge.exe"));
    }
    if (appData) {
      for (const year of ["2027", "2026", "2025", "2024", "2023", "2022", "2021"]) {
        candidates.push(path.join(appData, "Autodesk", "Revit", "Addins", year, "BIM-MODE", "bridge", "BimMode.Bridge.exe"));
      }
    }
    return candidates.find((p) => fs.existsSync(p)) || null;
  }

  const bridgeExe = findBridgeExe();
  if (!bridgeExe) {
    console.error(
      "[bim-mode-mcp] BimMode.Bridge.exe was not found on this PC.\n" +
      "Install the BIM-MODE Connector first:\n" +
      "  npx bim-mode-mcp --install 2026\n" +
      "or download the release from https://github.com/BIM-MODE/BIM-MODE-Connector/releases"
    );
    process.exit(1);
  }

  const child = spawn(bridgeExe, args, { stdio: "inherit" });
  child.on("exit", (code) => process.exit(code ?? 0));
  child.on("error", (err) => {
    console.error("[bim-mode-mcp] Failed to launch BimMode.Bridge.exe: " + err.message);
    process.exit(1);
  });
}
