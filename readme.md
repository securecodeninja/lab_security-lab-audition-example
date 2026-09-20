# Globomantics Command Injection Lab

This repository contains a guided security lab modeled on Pluralsight's lab format. The
learner discovers, exploits, and then remediates an OS command injection vulnerability
(CWE-78) in a small ASP.NET Core web application, playing the defender for the fictional
company Globomantics.

## What Gets Installed

The lab runs on a single Ubuntu virtual machine. The [setup.sh](./setup.sh) script
provisions everything automatically, with no manual steps required:

* Git
* .NET SDK 8.0
* Visual Studio Code
* Firefox

The script also clones this repository to the learner's Desktop, which includes the
vulnerable ASP.NET Core project used throughout the lab.

## Running the Lab

1. Run `setup.sh` on a fresh Ubuntu host to provision the environment.
2. Follow the guided walkthrough in [Lab Instructions](./Lab%20Instructions.md).

The walkthrough is designed to take roughly 15 to 20 minutes.

## Environment Summary

A single Ubuntu VM, and nothing else. The learner runs the ASP.NET Core application
locally with `dotnet run` (Kestrel on http://localhost:5265) and interacts with it in
Firefox on the same host. There are no external services and no additional machines,
which keeps the environment simple to recreate on a fresh Ubuntu instance.