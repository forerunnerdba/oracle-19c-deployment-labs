# Oracle Database 19c End-to-End Deployment on Oracle Linux 9.8 on Oracle Cloud

This repository contains the supporting execution log for my LinkedIn article documenting an end-to-end Oracle Database 19c deployment on **Oracle Linux 9.8 (OEL 9.8)** on Oracle Cloud.

The environment is configured as a **single-instance Oracle Restart environment using Oracle ASM / ASMLIB**.

## 📌 Overview

The deployment covers:

* Oracle Linux 9.8 preparation
* Required RPMs and OS configuration
* Oracle users and groups
* Filesystem, LVM and swap configuration
* Oracle ASM / ASMLIB 3.x
* ASM disk preparation
* Oracle Grid Infrastructure 19.3.0
* Oracle Restart configuration
* OPatch upgrade
* Grid Infrastructure 19.32.0 Release Update
* ASM configuration and disk group creation
* Oracle Database 19.3.0
* Database 19.32.0 Release Update
* DATA / REDO / FRA ASM disk groups
* Silent DBCA database creation
* Oracle Restart database registration
* OPatch and SQL patch validation
* Final ASM, Oracle Restart and database validation

## 🔍 Important OEL 9.8 Findings

During the deployment, Oracle Grid Infrastructure 19.3.0 encountered installation/configuration issues related to the OEL 9.8 environment and ASM disk discovery.

The tested solution was to:

1. Configure the OEL 9.8 prerequisites and ASMLIB.
2. Set the appropriate `CV_ASSUME_DISTID`.
3. Upgrade OPatch.
4. Patch the Grid Infrastructure home from **19.3.0 to 19.32.0** before completing the Grid installation.
5. Complete ASM configuration using ASMCA.
6. Create the remaining ASM disk groups.
7. Install and patch the Oracle Database home to 19.32.0.

The detailed errors, commands, troubleshooting steps and actual execution output are preserved in the log file.

👉 LinkedIn Article

The complete explanation of the deployment, configuration, troubleshooting and validation is documented in the LinkedIn article:

End-to-End Oracle Database 19c Deployment on Oracle Linux 9.8 - Oracle Restart, ASM & RU 19.32.0

## 📄 Installation Command & Execution Output

The complete command sequence and actual execution output are available here:

👉 **[Oracle 19c OEL 9.8 Installation Command & Execution Output](Oracle_19c_OEL9.8_Installation_Command_Output.log)**

The log contains the complete execution history from:

**OS preparation → ASM → Grid Infrastructure → Oracle Restart → Patching → Database Installation → DBCA → Validation**

## 🏗️ Environment

| Component           | Version / Configuration     |
| ------------------- | --------------------------- |
| Operating System    | Oracle Linux 9.8            |
| Cloud Platform      | Oracle Cloud Infrastructure |
| Grid Infrastructure | 19.3.0 → 19.32.0            |
| Database            | Oracle Database 19c         |
| Database RU         | 19.32.0                     |
| Storage             | Oracle ASM / ASMLIB         |
| High Availability   | Oracle Restart              |
| Database Type       | Single Instance / CDB       |
| Installation        | Silent Mode                 |
| Configuration       | Standalone Server           |
| CDB                 | PRIMCDB                     |
| PDB                 | PRIMPDB                     |

## ⚠️ Disclaimer

This repository documents a tested Oracle Database 19c deployment performed in a specific **Oracle Linux 9.8 / Oracle Cloud** environment.

The commands, paths, package versions, storage configuration and database parameters may need to be modified for other environments.

Always validate:

* Oracle certification and support requirements
* Oracle Linux requirements
* Storage configuration
* Device names before ASM operations
* Security requirements
* Backup and recovery requirements
* High availability requirements
* Organizational standards

Do not execute disk partitioning or ASM commands without first confirming the target devices.

## 🔐 Security

Passwords, private keys, tokens, credentials and other environment-specific secrets have been removed or replaced with placeholders before publication.

**Never commit production credentials or private keys to GitHub.**

## 👨‍💻 Author

**Chakravarthy P**

Oracle Database Administrator / SME

Areas of interest:

* Oracle Database
* Oracle RAC
* Oracle ASM
* Oracle Data Guard
* Oracle Restart
* Oracle Cloud
* Microsoft Azure
* Database Migration
* Oracle Patching
* Ansible Automation
* Linux

⭐ Feedback

If you find this documentation useful, feel free to share your feedback, suggestions or corrections. Please consider giving the repository a Star.

The objective is to continuously improve the documentation and capture practical Oracle DBA deployment experiences.
