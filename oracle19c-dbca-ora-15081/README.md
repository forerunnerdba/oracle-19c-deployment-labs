# Oracle 19c DBCA Failure – ORA-01501 / ORA-19502 / ORA-15081

## Overview

This repository documents a real-world Oracle Database 19c database creation issue encountered while creating a CDB using **DBCA with Oracle ASM**.

The database creation consistently failed at **9%** with:

```text
[FATAL] ORA-01501: CREATE DATABASE failed
ORA-19502: write error on file "+DATA/TESTCDB/CONTROLFILE/..."
ORA-15081: failed to submit an I/O operation to a disk
```

The error initially appeared to indicate an ASM/storage I/O problem.

After troubleshooting the ASM configuration, the issue was traced to the ASM diskgroup `compatible.rdbms` setting:

```text
compatible.rdbms = 10.1.0.0.0
```

After correcting the setting to:

```text
compatible.rdbms = 19.0.0.0.0
```

the database creation completed successfully.

---

## Environment

* Oracle Database 19c
* Oracle ASM
* Oracle Restart
* CDB / PDB
* ASM Diskgroups: `+DATA`, `+REDO`, `+FRA`, `+VOTK`

---

## Troubleshooting

The **complete troubleshooting session** is available in:

**[`ORA-01501_DBCA_FAILURE.log`](./ORA-01501_DBCA_FAILURE.log)**

The log contains the complete sequence of:

* DBCA database creation command
* Original error output
* DBCA log investigation
* ASM diskgroup compatibility checks
* `V$ASM_DISKGROUP` output
* `asmcmd lsattr` output
* Root-cause identification
* ASM compatibility correction
* Verification
* Successful DBCA database creation

For the complete command/output history, please refer to the log file.

---

## Root Cause

The ASM diskgroups had:

```text
compatible.asm   = 19.0.0.0.0
compatible.rdbms = 10.1.0.0.0
```

The `compatible.rdbms` attribute was corrected to:

```text
19.0.0.0.0
```

After the change, the database was successfully created.

---

## Result

### Before

```text
DBCA
  |
  +-- 9%
  |
  +-- ORA-01501
  +-- ORA-19502
  +-- ORA-15081
  |
  +-- Database Creation FAILED
```

### After

```text
DBCA
  |
  +-- 9%
  +-- Creating database files
  +-- Creating data dictionary
  +-- Creating PDB
  +-- Post Configuration
  |
  +-- 100%
  |
  +-- Database Creation SUCCESS
```

---

## Key Takeaway

**Don't always assume `ORA-15081` is a storage problem.**

When troubleshooting Oracle database creation failures involving ASM, check the ASM diskgroup attributes, including:

```text
compatible.asm
compatible.rdbms
```

The complete investigation and command history are preserved in the accompanying log file.

---

## Files

| File                         | Description                                  |
| ---------------------------- | -------------------------------------------- |
| `README.md`                  | Overview, root cause, and resolution         |
| `ORA-01501_DBCA_FAILURE.log` | Complete troubleshooting commands and output |

---

> **Note:** This repository is intended for troubleshooting reference and learning purposes. Review the impact of ASM compatibility changes carefully before applying similar changes in a production environment.
