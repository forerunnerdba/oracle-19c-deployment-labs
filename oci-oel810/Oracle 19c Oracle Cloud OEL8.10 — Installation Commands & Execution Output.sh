**********************************************************************************************************************************************************************
																			Pre-requisites
**********************************************************************************************************************************************************************

Link to download 19.32.0 RU. This is a bundle patch which has Database RU also
https://support.oracle.com/support/?patchId=39467003

 Patch No : 39467003
 Patch Name : GI RELEASE UPDATE 19.32.0.0.0(Patch:Linux x86-64) 
 Patch File Name: p39467003_190000_Linux-x86-64.zip (2.7 GB)
         
Link to download lates OPatch 
http://updates.oracle.com/ARULink/PatchDetails/process_form?patch_num=6880880
**********************************************************************************************************************************************************************
                                                Steps for Silent Installation of 19c on OEL8.10 with ASM
**********************************************************************************************************************************************************************

1. Create OS groups using the command below. Enter these commands as the 'root' user:

[opc@caoradb02 ~]$ sudo -i
[root@caoradb02 ~]# /usr/sbin/groupadd -g 501 oinstall
[root@caoradb02 ~]# /usr/sbin/groupadd -g 502 dba
[root@caoradb02 ~]# /usr/sbin/groupadd -g 503 asmdba
[root@caoradb02 ~]# /usr/sbin/groupadd -g 504 asmoper
[root@caoradb02 ~]# /usr/sbin/groupadd -g 506 asmadmin

(a) Create the users that will own the Oracle software using the commands:

[root@caoradb02 ~]# mkdir  /u01
[root@caoradb02 ~]# /usr/sbin/useradd -u 501 -g oinstall -G dba oracle
[root@caoradb02 ~]# chown -R oracle:oinstall /u01
[root@caoradb02 ~]# usermod  -G asmdba,asmoper,asmadmin,dba,oinstall oracle
[root@caoradb02 ~]# usermod -aG wheel oracle # This one we need when running cluster verification script with sudo
[root@caoradb02 ~]# id oracle
uid=501(oracle) gid=501(oinstall) groups=501(oinstall),10(wheel),502(dba),503(asmdba),504(asmoper),506(asmadmin)
[root@caoradb02 ~]#
[root@caoradb02 ~]# passwd oracle
Changing password for user oracle.
New password:
Retype new password:
passwd: all authentication tokens updated successfully.

(b) Create the Oracle Inventory Directory as 'oracle' user

[oracle@caoradb02 ~]$ mkdir -p /u01/app/oraInventory
[oracle@caoradb02 ~]$ chown -R oracle:oinstall /u01/app/oraInventory
[oracle@caoradb02 ~]$ chmod -R 775 /u01/app/oraInventory

(c) Creating the Oracle Grid Infrastructure Base and  Home Directory as 'oracle' user

[oracle@caoradb02 ~]$ mkdir -p /u01/app/19.3.0/db
[oracle@caoradb02 ~]$ mkdir -p /u01/app/19.3.0/grid
[oracle@caoradb02 ~]$ chown -R oracle:oinstall /u01/app/19.3.0/db
[oracle@caoradb02 ~]$ chown -R oracle:oinstall /u01/app/
[oracle@caoradb02 ~]$ chmod -R 775 /u01/app/19.3.0/grid
[oracle@caoradb02 ~]$
[oracle@caoradb02 ~]$ mkdir -p /u01/app/oracle/software
[oracle@caoradb02 ~]$ chown -R oracle:oinstall /u01/app/oracle/software

2. Expanding the existing partitions and creating required swap area as per oracle recommendation.

[root@caoradb02 ~]# growpart /dev/sda 3

CHANGED: partition=3 start=2304000 old: size=95422464 end=97726463 new: size=207411167 end=209715166

[root@caoradb02 ~]# lsblk
NAME               MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                  8:0    0  100G  0 disk
├─sda1               8:1    0  100M  0 part /boot/efi
├─sda2               8:2    0    1G  0 part /boot
└─sda3               8:3    0 98.9G  0 part
  ├─ocivolume-root 252:0    0 35.5G  0 lvm  /
  └─ocivolume-oled 252:1    0   10G  0 lvm  /var/oled
sdb                  8:16   0   50G  0 disk
sdc                  8:32   0   50G  0 disk
sdd                  8:48   0   50G  0 disk
sde                  8:64   0   50G  0 disk

#Creating Swap space in the existing volume group rootvg
[root@caoradb02 ~]# lvcreate -L 16G -n lv_swap ocivolume
  Logical volume "lv_swap" created.
  
#Check the existing swap space
[root@caoradb02 ~]# swapon -s
Filename                                Type            Size    Used    Priority
/.swapfile                              file            6291452 0       -2

#Turn off the existing swap area
[root@caoradb02 ~]# swapoff -v /.swapfile
swapoff /.swapfile

#Make swap area
[root@caoradb02 ~]# mkswap /dev/ocivolume/lv_swap
Setting up swapspace version 1, size = 16 GiB (17179865088 bytes)
no label, UUID=41c34aa7-c66f-472c-ad5c-c657cb675c1e

#Add new swap area details to fstab and also disable old swap entries in fstab
[root@caoradb02 ~]# vi /etc/fstab
/dev/ocivolume/lv_swap  swap swap defaults 0 0

#Activate the new swap area
[root@caoradb02 ~]# swapon -va
swapon: /dev/mapper/ocivolume-lv_swap: found signature [pagesize=4096, signature=swap]
swapon: /dev/mapper/ocivolume-lv_swap: pagesize=4096, swapsize=17179869184, devsize=17179869184
swapon /dev/mapper/ocivolume-lv_swap

#Check the swap area
[root@caoradb02 ~]# swapon -s
Filename                                Type            Size    Used    Priority
/dev/dm-2   
                            partition       16777212        0       -2

[root@caoradb02 ~]# free -m
              total        used        free      shared  buff/cache   available
Mem:          31800         635       21346           8        9818       30719
Swap:         16383           0       16383

#Extending the lvm to use 100% Free space in that particular partition
[root@caoradb02 ~]# lvextend -l +100%FREE /dev/ocivolume/root
  Size of logical volume ocivolume/root changed from 35.50 GiB (9088 extents) to <72.90 GiB (18662 extents).
  Logical volume ocivolume/root successfully resized.

#Even expanding the root lvm it won't take into affect in df -h even though it will show in lsblk. We need to run xfs_growfs or reboot the server 
[root@caoradb02 ~]# df -h
Filesystem                  Size  Used Avail Use% Mounted on
devtmpfs                     16G     0   16G   0% /dev
tmpfs                        16G     0   16G   0% /dev/shm
tmpfs                        16G  8.7M   16G   1% /run
tmpfs                        16G     0   16G   0% /sys/fs/cgroup
/dev/mapper/ocivolume-root   36G   21G   16G  58% /
/dev/sda2                  1014M  405M  610M  40% /boot
/dev/sda1                   100M  6.0M   94M   6% /boot/efi
/dev/mapper/ocivolume-oled   10G  113M  9.9G   2% /var/oled
tmpfs                       3.2G     0  3.2G   0% /run/user/986
tmpfs                       3.2G     0  3.2G   0% /run/user/1000
tmpfs                       3.2G     0  3.2G   0% /run/user/501

[root@caoradb02 ~]# lsblk
NAME                  MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                     8:0    0  100G  0 disk
├─sda1                  8:1    0  100M  0 part /boot/efi
├─sda2                  8:2    0    1G  0 part /boot
└─sda3                  8:3    0 98.9G  0 part
  ├─ocivolume-root    252:0    0 72.9G  0 lvm  /
  ├─ocivolume-oled    252:1    0   10G  0 lvm  /var/oled
  └─ocivolume-lv_swap 252:2    0   16G  0 lvm  [SWAP]
sdb                     8:16   0   50G  0 disk
sdc                     8:32   0   50G  0 disk
sdd                     8:48   0   50G  0 disk
sde                     8:64   0   50G  0 disk


#xfs_growfs would grow the partition without reboot. If we reboot after lvextend we don't need to run this xfs_growfs command.
[root@caoradb02 ~]# xfs_growfs /
meta-data=/dev/mapper/ocivolume-root isize=512    agcount=4, agsize=2326528 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=0
         =                       reflink=1    bigtime=0 inobtcount=0
data     =                       bsize=4096   blocks=9306112, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=4544, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
data blocks changed from 9306112 to 19109888

[root@caoradb02 ~]# df -h
Filesystem                  Size  Used Avail Use% Mounted on
devtmpfs                     16G     0   16G   0% /dev
tmpfs                        16G     0   16G   0% /dev/shm
tmpfs                        16G  8.7M   16G   1% /run
tmpfs                        16G     0   16G   0% /sys/fs/cgroup
/dev/mapper/ocivolume-root   73G   21G   53G  29% /
/dev/sda2                  1014M  405M  610M  40% /boot
/dev/sda1                   100M  6.0M   94M   6% /boot/efi
/dev/mapper/ocivolume-oled   10G  113M  9.9G   2% /var/oled
tmpfs                       3.2G     0  3.2G   0% /run/user/986
tmpfs                       3.2G     0  3.2G   0% /run/user/1000
tmpfs                       3.2G     0  3.2G   0% /run/user/501


**********************************************************************************************************************************************************************
                                                                            Grid Setup
**********************************************************************************************************************************************************************
3. Download the Grid and oracle 19c software from https://edelivery.oracle.com/osdc/faces/SoftwareDelivery -> Oracle Database 19c Enterprise Edition 19.3.0.0.0 as 'oracle' user

    Copy Installation Software to the Software Location

4. Unzip Grid Software to Grid Home Directory as 'oracle' user

unzip -q /u01/app/oracle/software/V982068-01.zip -d /u01/app/19.3.0/grid

5. Install required RPMs for Oracle Installation as 'root' user

cd /u01/app/oracle/software/

#Install required packages 
[root@caoradb02 ~]# dnf install -y perl xterm xhost
Ksplice for Oracle Linux 8 (x86_64)                                                                                                         66 MB/s |  75 MB     00:01
MySQL 8.4 Server Community for Oracle Linux 8 (x86_64)                                                                                     9.9 MB/s | 2.0 MB     00:00
MySQL 8.4 Tools Community for Oracle Linux 8 (x86_64)                                                                                      4.5 MB/s | 1.0 MB     00:00
MySQL Connectors Community for Oracle Linux 8 (x86_64)                                                                                     435 kB/s |  67 kB     00:00
Oracle Software for OCI users on Oracle Linux 8 (x86_64)                                                                                    40 MB/s | 181 MB     00:04
Oracle Linux 8 BaseOS Latest (x86_64)                                                                                                       55 MB/s | 160 MB     00:02
Oracle Linux 8 Application Stream (x86_64)                                                                                                  75 MB/s |  85 MB     00:01
Oracle Linux 8 Addons (x86_64)                                                                                                              43 MB/s |  69 MB     00:01
Latest Unbreakable Enterprise Kernel Release 7 for Oracle Linux 8 (x86_64)                                                                  63 MB/s | 116 MB     00:01
Dependencies resolved.
===========================================================================================================================================================================
 Package                                       Architecture            Version                                                    Repository                          Size
===========================================================================================================================================================================
Installing:
 perl                                          x86_64                  4:5.26.3-423.el8_10                                        ol8_appstream                       72 k
 xorg-x11-server-utils                         x86_64                  7.7-27.el8                                                 ol8_appstream                      198 k
 xterm                                         x86_64                  331-2.el8                                                  ol8_appstream                      529 k
Installing dependencies:
 annobin                                       x86_64                  11.13-2.0.6.el8                                            ol8_appstream                      972 k
 dwz                                           x86_64                  0.12-10.el8                                                ol8_appstream                      109 k
 efi-srpm-macros                               noarch                  3-3.0.1.el8                                                ol8_appstream                       22 k
 gcc-plugin-annobin                            x86_64                  8.5.0-28.0.1.el8_10                                        ol8_appstream                       47 k
 ghc-srpm-macros                               noarch                  1.4.2-7.el8                                                ol8_appstream                      9.3 k
 go-srpm-macros                                noarch                  2-17.el8                                                   ol8_appstream                       13 k
 libICE                                        x86_64                  1.0.9-15.el8                                               ol8_appstream                       74 k
 libSM                                         x86_64                  1.2.3-1.el8                                                ol8_appstream                       47 k
 libXaw                                        x86_64                  1.0.13-10.el8                                              ol8_appstream                      194 k
 libXcursor                                    x86_64                  1.1.15-3.el8                                               ol8_appstream                       36 k
 libXfixes                                     x86_64                  5.0.3-7.el8                                                ol8_appstream                       25 k
 libXft                                        x86_64                  2.3.3-1.el8                                                ol8_appstream                       67 k
 libXi                                         x86_64                  1.7.10-1.el8                                               ol8_appstream                       49 k
 libXinerama                                   x86_64                  1.1.4-1.el8                                                ol8_appstream                       15 k
 libXmu                                        x86_64                  1.1.3-1.el8                                                ol8_appstream                       75 k
 libXpm                                        x86_64                  3.5.12-11.el8                                              ol8_appstream                       58 k
 libXrandr                                     x86_64                  1.5.2-1.el8                                                ol8_appstream                       34 k
 libXt                                         x86_64                  1.1.5-12.el8                                               ol8_appstream                      185 k
 libXxf86misc                                  x86_64                  1.0.4-1.el8                                                ol8_appstream                       23 k
 libXxf86vm                                    x86_64                  1.1.4-9.el8                                                ol8_appstream                       19 k
 libfontenc                                    x86_64                  1.1.3-8.el8                                                ol8_appstream                       37 k
 libmcpp                                       x86_64                  2.7.2-20.el8                                               ol8_appstream                       81 k
 mcpp                                          x86_64                  2.7.2-20.el8                                               ol8_appstream                       31 k
 ocaml-srpm-macros                             noarch                  5-4.el8                                                    ol8_appstream                      9.3 k
 openblas-srpm-macros                          noarch                  2-2.el8                                                    ol8_appstream                      7.9 k
 perl-Algorithm-Diff                           noarch                  1.1903-9.el8                                               ol8_baseos_latest                   52 k
 perl-Archive-Tar                              noarch                  2.30-3.el8_10                                              ol8_appstream                       79 k
 perl-Archive-Zip                              noarch                  1.60-3.el8                                                 ol8_appstream                      108 k
 perl-Attribute-Handlers                       noarch                  0.99-423.el8_10                                            ol8_appstream                       88 k
 perl-B-Debug                                  noarch                  1.26-2.el8                                                 ol8_appstream                       26 k
 perl-CPAN                                     noarch                  2.18-402.el8_10                                            ol8_appstream                      574 k
 perl-CPAN-Meta                                noarch                  2.150010-396.el8                                           ol8_appstream                      191 k
 perl-CPAN-Meta-Requirements                   noarch                  2.140-396.el8                                              ol8_appstream                       37 k
 perl-CPAN-Meta-YAML                           noarch                  0.018-397.el8                                              ol8_appstream                       34 k
 perl-Compress-Bzip2                           x86_64                  2.26-6.el8                                                 ol8_appstream                       72 k
 perl-Compress-Raw-Bzip2                       x86_64                  2.081-1.el8                                                ol8_baseos_latest                   40 k
 perl-Compress-Raw-Zlib                        x86_64                  2.081-1.el8                                                ol8_baseos_latest                   68 k
 perl-Config-Perl-V                            noarch                  0.30-1.el8                                                 ol8_appstream                       22 k
 perl-DB_File                                  x86_64                  1.842-1.el8                                                ol8_appstream                       83 k
 perl-Data-OptList                             noarch                  0.110-6.el8                                                ol8_appstream                       31 k
 perl-Data-Section                             noarch                  0.200007-3.el8                                             ol8_appstream                       30 k
 perl-Devel-PPPort                             x86_64                  3.36-5.el8                                                 ol8_appstream                      118 k
 perl-Devel-Peek                               x86_64                  1.26-423.el8_10                                            ol8_appstream                       93 k
 perl-Devel-SelfStubber                        noarch                  1.06-423.el8_10                                            ol8_appstream                       75 k
 perl-Devel-Size                               x86_64                  0.81-2.el8                                                 ol8_appstream                       34 k
 perl-Digest-SHA                               x86_64                  1:6.02-1.el8                                               ol8_appstream                       66 k
 perl-Encode-devel                             x86_64                  4:2.97-3.el8                                               ol8_appstream                       39 k
 perl-Env                                      noarch                  1.04-395.el8                                               ol8_appstream                       21 k
 perl-ExtUtils-CBuilder                        noarch                  1:0.280230-2.el8                                           ol8_appstream                       48 k
 perl-ExtUtils-Command                         noarch                  1:7.34-1.el8                                               ol8_appstream                       19 k
 perl-ExtUtils-Embed                           noarch                  1.34-423.el8_10                                            ol8_appstream                       78 k
 perl-ExtUtils-Install                         noarch                  2.14-4.el8                                                 ol8_appstream                       46 k
 perl-ExtUtils-MM-Utils                        noarch                  1:7.34-1.el8                                               ol8_appstream                       16 k
 perl-ExtUtils-MakeMaker                       noarch                  1:7.34-1.el8                                               ol8_appstream                      300 k
 perl-ExtUtils-Manifest                        noarch                  1.70-395.el8                                               ol8_appstream                       36 k
 perl-ExtUtils-Miniperl                        noarch                  1.06-423.el8_10                                            ol8_appstream                       76 k
 perl-ExtUtils-ParseXS                         noarch                  1:3.35-2.el8                                               ol8_appstream                       83 k
 perl-File-Fetch                               noarch                  0.56-2.el8                                                 ol8_appstream                       33 k
 perl-File-HomeDir                             noarch                  1.002-4.el8                                                ol8_appstream                       61 k
 perl-File-Which                               noarch                  1.22-2.el8                                                 ol8_appstream                       23 k
 perl-Filter                                   x86_64                  2:1.58-2.el8                                               ol8_appstream                       82 k
 perl-Filter-Simple                            noarch                  0.94-2.el8                                                 ol8_appstream                       29 k
 perl-IO-Compress                              noarch                  2.081-2.el8_10                                             ol8_appstream                      257 k
 perl-IO-Zlib                                  noarch                  1:1.10-423.el8_10                                          ol8_appstream                       80 k
 perl-IPC-Cmd                                  noarch                  2:1.02-1.el8                                               ol8_appstream                       43 k
 perl-IPC-SysV                                 x86_64                  2.07-397.el8                                               ol8_appstream                       43 k
 perl-JSON-PP                                  noarch                  1:2.97.001-3.el8                                           ol8_appstream                       68 k
 perl-Locale-Codes                             noarch                  3.57-1.el8                                                 ol8_appstream                      310 k
 perl-Locale-Maketext                          noarch                  1.28-396.el8                                               ol8_appstream                       99 k
 perl-Locale-Maketext-Simple                   noarch                  1:0.21-423.el8_10                                          ol8_appstream                       78 k
 perl-MRO-Compat                               noarch                  0.13-4.el8                                                 ol8_appstream                       24 k
 perl-Math-BigInt                              noarch                  1:1.9998.11-7.el8                                          ol8_baseos_latest                  196 k
 perl-Math-BigInt-FastCalc                     x86_64                  0.500.600-6.el8                                            ol8_appstream                       27 k
 perl-Math-BigRat                              noarch                  0.2614-1.el8                                               ol8_appstream                       40 k
 perl-Math-Complex                             noarch                  1.59-423.el8_10                                            ol8_baseos_latest                  108 k
 perl-Memoize                                  noarch                  1.03-423.el8_10                                            ol8_appstream                      118 k
 perl-Module-Build                             noarch                  2:0.42.24-5.el8                                            ol8_appstream                      273 k
 perl-Module-CoreList                          noarch                  1:5.20181130-1.el8                                         ol8_appstream                       87 k
 perl-Module-CoreList-tools                    noarch                  1:5.20181130-1.el8                                         ol8_appstream                       22 k
 perl-Module-Load                              noarch                  1:0.32-395.el8                                             ol8_appstream                       19 k
 perl-Module-Load-Conditional                  noarch                  0.68-395.el8                                               ol8_appstream                       24 k
 perl-Module-Loaded                            noarch                  1:0.08-423.el8_10                                          ol8_appstream                       74 k
 perl-Module-Metadata                          noarch                  1.000033-395.el8                                           ol8_appstream                       44 k
 perl-Net-Ping                                 noarch                  2.55-423.el8_10                                            ol8_appstream                      101 k
 perl-Package-Generator                        noarch                  1.106-11.el8                                               ol8_appstream                       27 k
 perl-Params-Check                             noarch                  1:0.38-395.el8                                             ol8_appstream                       24 k
 perl-Params-Util                              x86_64                  1.07-22.el8                                                ol8_appstream                       44 k
 perl-Perl-OSType                              noarch                  1.010-396.el8                                              ol8_appstream                       29 k
 perl-PerlIO-via-QuotedPrint                   noarch                  0.08-395.el8                                               ol8_appstream                       13 k
 perl-Pod-Checker                              noarch                  4:1.73-395.el8                                             ol8_appstream                       33 k
 perl-Pod-Html                                 noarch                  1.22.02-423.el8_10                                         ol8_appstream                       87 k
 perl-Pod-Parser                               noarch                  1.63-396.el8                                               ol8_appstream                      108 k
 perl-SelfLoader                               noarch                  1.23-423.el8_10                                            ol8_appstream                       82 k
 perl-Software-License                         noarch                  0.103013-2.el8                                             ol8_appstream                      137 k
 perl-Sub-Exporter                             noarch                  0.987-15.el8                                               ol8_appstream                       73 k
 perl-Sub-Install                              noarch                  0.928-14.el8                                               ol8_appstream                       27 k
 perl-Sys-Syslog                               x86_64                  0.35-397.el8                                               ol8_appstream                       50 k
 perl-Test                                     noarch                  1.30-423.el8_10                                            ol8_appstream                       89 k
 perl-Test-Harness                             noarch                  1:3.42-1.el8                                               ol8_appstream                      279 k
 perl-Test-Simple                              noarch                  1:1.302135-1.el8                                           ol8_appstream                      516 k
 perl-Text-Balanced                            noarch                  2.03-395.el8                                               ol8_appstream                       58 k
 perl-Text-Diff                                noarch                  1.45-2.el8                                                 ol8_baseos_latest                   45 k
 perl-Text-Glob                                noarch                  0.11-4.el8                                                 ol8_appstream                       17 k
 perl-Text-Template                            noarch                  1.51-1.el8                                                 ol8_appstream                       64 k
 perl-Thread-Queue                             noarch                  3.13-1.el8                                                 ol8_appstream                       24 k
 perl-Time-HiRes                               x86_64                  4:1.9758-2.el8                                             ol8_appstream                       61 k
 perl-Time-Piece                               x86_64                  1.31-423.el8_10                                            ol8_appstream                       97 k
 perl-Unicode-Collate                          x86_64                  1.25-2.el8                                                 ol8_appstream                      686 k
 perl-bignum                                   noarch                  0.49-2.el8                                                 ol8_appstream                       43 k
 perl-devel                                    x86_64                  4:5.26.3-423.el8_10                                        ol8_appstream                      599 k
 perl-encoding                                 x86_64                  4:2.22-3.el8                                               ol8_appstream                       68 k
 perl-experimental                             noarch                  0.019-2.el8                                                ol8_appstream                       24 k
 perl-inc-latest                               noarch                  2:0.500-9.el8                                              ol8_appstream                       25 k
 perl-libnetcfg                                noarch                  4:5.26.3-423.el8_10                                        ol8_appstream                       77 k
 perl-local-lib                                noarch                  2.000024-2.el8                                             ol8_appstream                       74 k
 perl-open                                     noarch                  1.11-423.el8_10                                            ol8_appstream                       77 k
 perl-perlfaq                                  noarch                  5.20180605-1.el8                                           ol8_appstream                      386 k
 perl-srpm-macros                              noarch                  1-25.el8                                                   ol8_appstream                       11 k
 perl-utils                                    noarch                  5.26.3-423.el8_10                                          ol8_appstream                      128 k
 perl-version                                  x86_64                  6:0.99.24-1.el8                                            ol8_appstream                       67 k
 python-rpm-macros                             noarch                  3-45.el8                                                   ol8_appstream                       16 k
 python-srpm-macros                            noarch                  3-45.el8                                                   ol8_appstream                       16 k
 python3-rpm-macros                            noarch                  3-45.el8                                                   ol8_appstream                       15 k
 qt5-srpm-macros                               noarch                  5.15.3-1.el8                                               ol8_appstream                       11 k
 redhat-rpm-config                             noarch                  131-1.0.1.el8                                              ol8_appstream                       91 k
 rust-srpm-macros                              noarch                  5-2.el8                                                    ol8_appstream                      9.2 k
 xorg-x11-font-utils                           x86_64                  1:7.5-41.el8                                               ol8_appstream                      104 k
 xterm-resize                                  x86_64                  331-2.el8                                                  ol8_appstream                       38 k
Installing weak dependencies:
 perl-Encode-Locale                            noarch                  1.05-10.0.1.module+el8.3.0+90378+3cefc087                  ol8_appstream                       21 k
 perl-TermReadKey                              x86_64                  2.37-7.el8                                                 ol8_appstream                       40 k
 xorg-x11-fonts-misc                           noarch                  7.5-19.el8                                                 ol8_appstream                      5.8 M
Downgrading:
 dtrace                                        x86_64                  2.0.1-1.el8                                                ol8_UEKR7                          4.7 M

Transaction Summary
===========================================================================================================================================================================
Install    134 Packages
Downgrade    1 Package

Total download size: 23 M
Downloading Packages:
(1/135): perl-Compress-Raw-Bzip2-2.081-1.el8.x86_64.rpm                                                                                    892 kB/s |  40 kB     00:00
(2/135): perl-Algorithm-Diff-1.1903-9.el8.noarch.rpm                                                                                       1.0 MB/s |  52 kB     00:00
(3/135): perl-Compress-Raw-Zlib-2.081-1.el8.x86_64.rpm                                                                                     6.0 MB/s |  68 kB     00:00
(4/135): perl-Math-BigInt-1.9998.11-7.el8.noarch.rpm                                                                                        15 MB/s | 196 kB     00:00
(5/135): perl-Text-Diff-1.45-2.el8.noarch.rpm                                                                                              8.7 MB/s |  45 kB     00:00
(6/135): perl-Math-Complex-1.59-423.el8_10.noarch.rpm                                                                                      7.7 MB/s | 108 kB     00:00
(7/135): dwz-0.12-10.el8.x86_64.rpm                                                                                                         13 MB/s | 109 kB     00:00
(8/135): efi-srpm-macros-3-3.0.1.el8.noarch.rpm                                                                                            2.3 MB/s |  22 kB     00:00
(9/135): gcc-plugin-annobin-8.5.0-28.0.1.el8_10.x86_64.rpm                                                                                 9.5 MB/s |  47 kB     00:00
(10/135): ghc-srpm-macros-1.4.2-7.el8.noarch.rpm                                                                                           1.1 MB/s | 9.3 kB     00:00
(11/135): annobin-11.13-2.0.6.el8.x86_64.rpm                                                                                                21 MB/s | 972 kB     00:00
(12/135): go-srpm-macros-2-17.el8.noarch.rpm                                                                                               1.1 MB/s |  13 kB     00:00
(13/135): libICE-1.0.9-15.el8.x86_64.rpm                                                                                                   9.5 MB/s |  74 kB     00:00
(14/135): libSM-1.2.3-1.el8.x86_64.rpm                                                                                                     6.3 MB/s |  47 kB     00:00
(15/135): libXcursor-1.1.15-3.el8.x86_64.rpm                                                                                               7.5 MB/s |  36 kB     00:00
(16/135): libXaw-1.0.13-10.el8.x86_64.rpm                                                                                                   16 MB/s | 194 kB     00:00
(17/135): libXfixes-5.0.3-7.el8.x86_64.rpm                                                                                                 3.4 MB/s |  25 kB     00:00
(18/135): libXft-2.3.3-1.el8.x86_64.rpm                                                                                                    9.1 MB/s |  67 kB     00:00
(19/135): libXi-1.7.10-1.el8.x86_64.rpm                                                                                                    6.3 MB/s |  49 kB     00:00
(20/135): libXinerama-1.1.4-1.el8.x86_64.rpm                                                                                               2.5 MB/s |  15 kB     00:00
(21/135): libXmu-1.1.3-1.el8.x86_64.rpm                                                                                                     11 MB/s |  75 kB     00:00
(22/135): libXpm-3.5.12-11.el8.x86_64.rpm                                                                                                  7.2 MB/s |  58 kB     00:00
(23/135): libXrandr-1.5.2-1.el8.x86_64.rpm                                                                                                 5.0 MB/s |  34 kB     00:00
(24/135): libXxf86misc-1.0.4-1.el8.x86_64.rpm                                                                                              5.6 MB/s |  23 kB     00:00
(25/135): libXt-1.1.5-12.el8.x86_64.rpm                                                                                                     14 MB/s | 185 kB     00:00
(26/135): libXxf86vm-1.1.4-9.el8.x86_64.rpm                                                                                                2.4 MB/s |  19 kB     00:00
(27/135): libfontenc-1.1.3-8.el8.x86_64.rpm                                                                                                6.2 MB/s |  37 kB     00:00
(28/135): libmcpp-2.7.2-20.el8.x86_64.rpm                                                                                                  9.6 MB/s |  81 kB     00:00
(29/135): mcpp-2.7.2-20.el8.x86_64.rpm                                                                                                     4.0 MB/s |  31 kB     00:00
(30/135): ocaml-srpm-macros-5-4.el8.noarch.rpm                                                                                             1.7 MB/s | 9.3 kB     00:00
(31/135): openblas-srpm-macros-2-2.el8.noarch.rpm                                                                                          1.6 MB/s | 7.9 kB     00:00
(32/135): perl-5.26.3-423.el8_10.x86_64.rpm                                                                                                 11 MB/s |  72 kB     00:00
(33/135): perl-Archive-Tar-2.30-3.el8_10.noarch.rpm                                                                                        9.4 MB/s |  79 kB     00:00
(34/135): perl-Archive-Zip-1.60-3.el8.noarch.rpm                                                                                            11 MB/s | 108 kB     00:00
(35/135): perl-Attribute-Handlers-0.99-423.el8_10.noarch.rpm                                                                               8.4 MB/s |  88 kB     00:00
(36/135): perl-B-Debug-1.26-2.el8.noarch.rpm                                                                                               3.4 MB/s |  26 kB     00:00
(37/135): perl-CPAN-Meta-2.150010-396.el8.noarch.rpm                                                                                        17 MB/s | 191 kB     00:00
(38/135): perl-CPAN-Meta-Requirements-2.140-396.el8.noarch.rpm                                                                             6.7 MB/s |  37 kB     00:00
(39/135): perl-CPAN-Meta-YAML-0.018-397.el8.noarch.rpm                                                                                     7.5 MB/s |  34 kB     00:00
(40/135): perl-CPAN-2.18-402.el8_10.noarch.rpm                                                                                              17 MB/s | 574 kB     00:00
(41/135): perl-Compress-Bzip2-2.26-6.el8.x86_64.rpm                                                                                        6.1 MB/s |  72 kB     00:00
(42/135): perl-Config-Perl-V-0.30-1.el8.noarch.rpm                                                                                         3.1 MB/s |  22 kB     00:00
(43/135): perl-DB_File-1.842-1.el8.x86_64.rpm                                                                                               11 MB/s |  83 kB     00:00
(44/135): perl-Data-OptList-0.110-6.el8.noarch.rpm                                                                                         3.8 MB/s |  31 kB     00:00
(45/135): perl-Data-Section-0.200007-3.el8.noarch.rpm                                                                                      4.8 MB/s |  30 kB     00:00
(46/135): perl-Devel-PPPort-3.36-5.el8.x86_64.rpm                                                                                           13 MB/s | 118 kB     00:00
(47/135): perl-Devel-Peek-1.26-423.el8_10.x86_64.rpm                                                                                       9.2 MB/s |  93 kB     00:00
(48/135): perl-Devel-SelfStubber-1.06-423.el8_10.noarch.rpm                                                                                9.5 MB/s |  75 kB     00:00
(49/135): perl-Devel-Size-0.81-2.el8.x86_64.rpm                                                                                            4.6 MB/s |  34 kB     00:00
(50/135): perl-Digest-SHA-6.02-1.el8.x86_64.rpm                                                                                            8.8 MB/s |  66 kB     00:00
(51/135): dtrace-2.0.1-1.el8.x86_64.rpm                                                                                                     15 MB/s | 4.7 MB     00:00
(52/135): perl-Encode-devel-2.97-3.el8.x86_64.rpm                                                                                          1.2 MB/s |  39 kB     00:00
(53/135): perl-ExtUtils-CBuilder-0.280230-2.el8.noarch.rpm                                                                                 9.7 MB/s |  48 kB     00:00
(54/135): perl-Env-1.04-395.el8.noarch.rpm                                                                                                 1.9 MB/s |  21 kB     00:00
(55/135): perl-ExtUtils-Command-7.34-1.el8.noarch.rpm                                                                                      3.6 MB/s |  19 kB     00:00
(56/135): perl-ExtUtils-Embed-1.34-423.el8_10.noarch.rpm                                                                                    12 MB/s |  78 kB     00:00
(57/135): perl-ExtUtils-Install-2.14-4.el8.noarch.rpm                                                                                      6.6 MB/s |  46 kB     00:00
(58/135): perl-ExtUtils-MM-Utils-7.34-1.el8.noarch.rpm                                                                                     2.1 MB/s |  16 kB     00:00
(59/135): perl-ExtUtils-Manifest-1.70-395.el8.noarch.rpm                                                                                   7.6 MB/s |  36 kB     00:00
(60/135): perl-Encode-Locale-1.05-10.0.1.module+el8.3.0+90378+3cefc087.noarch.rpm                                                          302 kB/s |  21 kB     00:00
(61/135): perl-ExtUtils-MakeMaker-7.34-1.el8.noarch.rpm                                                                                     16 MB/s | 300 kB     00:00
(62/135): perl-ExtUtils-Miniperl-1.06-423.el8_10.noarch.rpm                                                                                6.6 MB/s |  76 kB     00:00
(63/135): perl-ExtUtils-ParseXS-3.35-2.el8.noarch.rpm                                                                                      7.0 MB/s |  83 kB     00:00
(64/135): perl-File-Fetch-0.56-2.el8.noarch.rpm                                                                                            3.2 MB/s |  33 kB     00:00
(65/135): perl-File-Which-1.22-2.el8.noarch.rpm                                                                                            4.0 MB/s |  23 kB     00:00
(66/135): perl-File-HomeDir-1.002-4.el8.noarch.rpm                                                                                         4.3 MB/s |  61 kB     00:00
(67/135): perl-Filter-Simple-0.94-2.el8.noarch.rpm                                                                                         3.8 MB/s |  29 kB     00:00
(68/135): perl-Filter-1.58-2.el8.x86_64.rpm                                                                                                5.6 MB/s |  82 kB     00:00
(69/135): perl-IO-Zlib-1.10-423.el8_10.noarch.rpm                                                                                          9.3 MB/s |  80 kB     00:00
(70/135): perl-IPC-Cmd-1.02-1.el8.noarch.rpm                                                                                               5.9 MB/s |  43 kB     00:00
(71/135): perl-IPC-SysV-2.07-397.el8.x86_64.rpm                                                                                            7.6 MB/s |  43 kB     00:00
(72/135): perl-IO-Compress-2.081-2.el8_10.noarch.rpm                                                                                        12 MB/s | 257 kB     00:00
(73/135): perl-JSON-PP-2.97.001-3.el8.noarch.rpm                                                                                           6.6 MB/s |  68 kB     00:00
(74/135): perl-Locale-Maketext-1.28-396.el8.noarch.rpm                                                                                      13 MB/s |  99 kB     00:00
(75/135): perl-Locale-Maketext-Simple-0.21-423.el8_10.noarch.rpm                                                                           8.9 MB/s |  78 kB     00:00
(76/135): perl-MRO-Compat-0.13-4.el8.noarch.rpm                                                                                            3.3 MB/s |  24 kB     00:00
(77/135): perl-Math-BigInt-FastCalc-0.500.600-6.el8.x86_64.rpm                                                                             4.6 MB/s |  27 kB     00:00
(78/135): perl-Math-BigRat-0.2614-1.el8.noarch.rpm                                                                                         7.1 MB/s |  40 kB     00:00
(79/135): perl-Locale-Codes-3.57-1.el8.noarch.rpm                                                                                           10 MB/s | 310 kB     00:00
(80/135): perl-Memoize-1.03-423.el8_10.noarch.rpm                                                                                          9.3 MB/s | 118 kB     00:00
(81/135): perl-Module-CoreList-5.20181130-1.el8.noarch.rpm                                                                                 9.6 MB/s |  87 kB     00:00
(82/135): perl-Module-CoreList-tools-5.20181130-1.el8.noarch.rpm                                                                           3.5 MB/s |  22 kB     00:00
(83/135): perl-Module-Load-0.32-395.el8.noarch.rpm                                                                                         4.2 MB/s |  19 kB     00:00
(84/135): perl-Module-Build-0.42.24-5.el8.noarch.rpm                                                                                        12 MB/s | 273 kB     00:00
(85/135): perl-Module-Load-Conditional-0.68-395.el8.noarch.rpm                                                                             3.0 MB/s |  24 kB     00:00
(86/135): perl-Module-Loaded-0.08-423.el8_10.noarch.rpm                                                                                    7.8 MB/s |  74 kB     00:00
(87/135): perl-Module-Metadata-1.000033-395.el8.noarch.rpm                                                                                 5.6 MB/s |  44 kB     00:00
(88/135): perl-Package-Generator-1.106-11.el8.noarch.rpm                                                                                   5.3 MB/s |  27 kB     00:00
(89/135): perl-Params-Check-0.38-395.el8.noarch.rpm                                                                                        4.4 MB/s |  24 kB     00:00
(90/135): perl-Net-Ping-2.55-423.el8_10.noarch.rpm                                                                                         6.7 MB/s | 101 kB     00:00
(91/135): perl-Params-Util-1.07-22.el8.x86_64.rpm                                                                                          5.2 MB/s |  44 kB     00:00
(92/135): perl-Perl-OSType-1.010-396.el8.noarch.rpm                                                                                        3.4 MB/s |  29 kB     00:00
(93/135): perl-PerlIO-via-QuotedPrint-0.08-395.el8.noarch.rpm                                                                              1.6 MB/s |  13 kB     00:00
(94/135): perl-Pod-Checker-1.73-395.el8.noarch.rpm                                                                                         3.6 MB/s |  33 kB     00:00
(95/135): perl-Pod-Html-1.22.02-423.el8_10.noarch.rpm                                                                                       11 MB/s |  87 kB     00:00
(96/135): perl-Pod-Parser-1.63-396.el8.noarch.rpm                                                                                          9.8 MB/s | 108 kB     00:00
(97/135): perl-SelfLoader-1.23-423.el8_10.noarch.rpm                                                                                       6.7 MB/s |  82 kB     00:00
(98/135): perl-Sub-Exporter-0.987-15.el8.noarch.rpm                                                                                        8.7 MB/s |  73 kB     00:00
(99/135): perl-Software-License-0.103013-2.el8.noarch.rpm                                                                                  8.8 MB/s | 137 kB     00:00
(100/135): perl-Sub-Install-0.928-14.el8.noarch.rpm                                                                                        2.9 MB/s |  27 kB     00:00
(101/135): perl-Sys-Syslog-0.35-397.el8.x86_64.rpm                                                                                         6.2 MB/s |  50 kB     00:00
(102/135): perl-TermReadKey-2.37-7.el8.x86_64.rpm                                                                                          6.3 MB/s |  40 kB     00:00
(103/135): perl-Test-1.30-423.el8_10.noarch.rpm                                                                                            9.0 MB/s |  89 kB     00:00
(104/135): perl-Text-Balanced-2.03-395.el8.noarch.rpm                                                                                      9.7 MB/s |  58 kB     00:00
(105/135): perl-Test-Harness-3.42-1.el8.noarch.rpm                                                                                          15 MB/s | 279 kB     00:00
(106/135): perl-Text-Glob-0.11-4.el8.noarch.rpm                                                                                            2.5 MB/s |  17 kB     00:00
(107/135): perl-Text-Template-1.51-1.el8.noarch.rpm                                                                                        9.9 MB/s |  64 kB     00:00
(108/135): perl-Thread-Queue-3.13-1.el8.noarch.rpm                                                                                         3.4 MB/s |  24 kB     00:00
(109/135): perl-Time-HiRes-1.9758-2.el8.x86_64.rpm                                                                                          10 MB/s |  61 kB     00:00
(110/135): perl-Test-Simple-1.302135-1.el8.noarch.rpm                                                                                       14 MB/s | 516 kB     00:00
(111/135): perl-Time-Piece-1.31-423.el8_10.x86_64.rpm                                                                                      7.0 MB/s |  97 kB     00:00
(112/135): perl-bignum-0.49-2.el8.noarch.rpm                                                                                               7.1 MB/s |  43 kB     00:00
(113/135): perl-encoding-2.22-3.el8.x86_64.rpm                                                                                              13 MB/s |  68 kB     00:00
(114/135): perl-experimental-0.019-2.el8.noarch.rpm                                                                                        3.5 MB/s |  24 kB     00:00
(115/135): perl-inc-latest-0.500-9.el8.noarch.rpm                                                                                          6.8 MB/s |  25 kB     00:00
(116/135): perl-devel-5.26.3-423.el8_10.x86_64.rpm                                                                                          22 MB/s | 599 kB     00:00
(117/135): perl-libnetcfg-5.26.3-423.el8_10.noarch.rpm                                                                                     6.5 MB/s |  77 kB     00:00
(118/135): perl-Unicode-Collate-1.25-2.el8.x86_64.rpm                                                                                       14 MB/s | 686 kB     00:00
(119/135): perl-local-lib-2.000024-2.el8.noarch.rpm                                                                                        5.0 MB/s |  74 kB     00:00
(120/135): perl-open-1.11-423.el8_10.noarch.rpm                                                                                            5.6 MB/s |  77 kB     00:00
(121/135): perl-srpm-macros-1-25.el8.noarch.rpm                                                                                            2.0 MB/s |  11 kB     00:00
(122/135): perl-utils-5.26.3-423.el8_10.noarch.rpm                                                                                          16 MB/s | 128 kB     00:00
(123/135): perl-version-0.99.24-1.el8.x86_64.rpm                                                                                           7.5 MB/s |  67 kB     00:00
(124/135): python-rpm-macros-3-45.el8.noarch.rpm                                                                                           2.8 MB/s |  16 kB     00:00
(125/135): python-srpm-macros-3-45.el8.noarch.rpm                                                                                          3.5 MB/s |  16 kB     00:00
(126/135): python3-rpm-macros-3-45.el8.noarch.rpm                                                                                          3.1 MB/s |  15 kB     00:00
(127/135): qt5-srpm-macros-5.15.3-1.el8.noarch.rpm                                                                                         2.1 MB/s |  11 kB     00:00
(128/135): perl-perlfaq-5.20180605-1.el8.noarch.rpm                                                                                         11 MB/s | 386 kB     00:00
(129/135): rust-srpm-macros-5-2.el8.noarch.rpm                                                                                             1.1 MB/s | 9.2 kB     00:00
(130/135): redhat-rpm-config-131-1.0.1.el8.noarch.rpm                                                                                      6.1 MB/s |  91 kB     00:00
(131/135): xorg-x11-font-utils-7.5-41.el8.x86_64.rpm                                                                                       9.4 MB/s | 104 kB     00:00
(132/135): xorg-x11-server-utils-7.7-27.el8.x86_64.rpm                                                                                      17 MB/s | 198 kB     00:00
(133/135): xterm-resize-331-2.el8.x86_64.rpm                                                                                               8.0 MB/s |  38 kB     00:00
(134/135): xterm-331-2.el8.x86_64.rpm                                                                                                       21 MB/s | 529 kB     00:00
(135/135): xorg-x11-fonts-misc-7.5-19.el8.noarch.rpm                                                                                        57 MB/s | 5.8 MB     00:00
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                                       31 MB/s |  23 MB     00:00
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                                   1/1
  Running scriptlet: perl-version-6:0.99.24-1.el8.x86_64                                                                                                               1/1
  Installing       : perl-version-6:0.99.24-1.el8.x86_64                                                                                                             1/136
  Installing       : perl-Time-HiRes-4:1.9758-2.el8.x86_64                                                                                                           2/136
  Installing       : perl-CPAN-Meta-Requirements-2.140-396.el8.noarch                                                                                                3/136
  Installing       : perl-ExtUtils-ParseXS-1:3.35-2.el8.noarch                                                                                                       4/136
  Installing       : perl-ExtUtils-Manifest-1.70-395.el8.noarch                                                                                                      5/136
  Installing       : libICE-1.0.9-15.el8.x86_64                                                                                                                      6/136
  Installing       : perl-Test-Harness-1:3.42-1.el8.noarch                                                                                                           7/136
  Installing       : perl-Module-CoreList-1:5.20181130-1.el8.noarch                                                                                                  8/136
  Installing       : perl-Module-Metadata-1.000033-395.el8.noarch                                                                                                    9/136
  Installing       : python-srpm-macros-3-45.el8.noarch                                                                                                             10/136
  Installing       : perl-SelfLoader-1.23-423.el8_10.noarch                                                                                                         11/136
  Installing       : perl-Perl-OSType-1.010-396.el8.noarch                                                                                                          12/136
  Installing       : perl-Module-Load-1:0.32-395.el8.noarch                                                                                                         13/136
  Installing       : perl-Filter-2:1.58-2.el8.x86_64                                                                                                                14/136
  Installing       : perl-Compress-Raw-Zlib-2.081-1.el8.x86_64                                                                                                      15/136
  Installing       : perl-encoding-4:2.22-3.el8.x86_64                                                                                                              16/136
  Installing       : perl-Text-Balanced-2.03-395.el8.noarch                                                                                                         17/136
  Installing       : perl-Net-Ping-2.55-423.el8_10.noarch                                                                                                           18/136
  Installing       : perl-Sub-Install-0.928-14.el8.noarch                                                                                                           19/136
  Installing       : perl-Pod-Html-1.22.02-423.el8_10.noarch                                                                                                        20/136
  Installing       : perl-Params-Util-1.07-22.el8.x86_64                                                                                                            21/136
  Installing       : perl-Locale-Maketext-1.28-396.el8.noarch                                                                                                       22/136
  Installing       : perl-Locale-Maketext-Simple-1:0.21-423.el8_10.noarch                                                                                           23/136
  Installing       : perl-Params-Check-1:0.38-395.el8.noarch                                                                                                        24/136
  Installing       : perl-Module-Load-Conditional-0.68-395.el8.noarch                                                                                               25/136
  Installing       : perl-ExtUtils-Command-1:7.34-1.el8.noarch                                                                                                      26/136
  Installing       : perl-Digest-SHA-1:6.02-1.el8.x86_64                                                                                                            27/136
  Installing       : perl-CPAN-Meta-YAML-0.018-397.el8.noarch                                                                                                       28/136
  Installing       : libXpm-3.5.12-11.el8.x86_64                                                                                                                    29/136
  Installing       : perl-Math-Complex-1.59-423.el8_10.noarch                                                                                                       30/136
  Installing       : perl-Math-BigInt-1:1.9998.11-7.el8.noarch                                                                                                      31/136
  Installing       : perl-JSON-PP-1:2.97.001-3.el8.noarch                                                                                                           32/136
  Installing       : perl-CPAN-Meta-2.150010-396.el8.noarch                                                                                                         33/136
  Installing       : perl-Math-BigRat-0.2614-1.el8.noarch                                                                                                           34/136
  Installing       : perl-Compress-Raw-Bzip2-2.081-1.el8.x86_64                                                                                                     35/136
  Installing       : perl-IO-Compress-2.081-2.el8_10.noarch                                                                                                         36/136
  Installing       : perl-IO-Zlib-1:1.10-423.el8_10.noarch                                                                                                          37/136
  Installing       : perl-bignum-0.49-2.el8.noarch                                                                                                                  38/136
  Installing       : perl-Math-BigInt-FastCalc-0.500.600-6.el8.x86_64                                                                                               39/136
  Installing       : perl-Data-OptList-0.110-6.el8.noarch                                                                                                           40/136
  Installing       : perl-Filter-Simple-0.94-2.el8.noarch                                                                                                           41/136
  Installing       : perl-open-1.11-423.el8_10.noarch                                                                                                               42/136
  Installing       : perl-Archive-Zip-1.60-3.el8.noarch                                                                                                             43/136
  Installing       : perl-Devel-SelfStubber-1.06-423.el8_10.noarch                                                                                                  44/136
  Installing       : python-rpm-macros-3-45.el8.noarch                                                                                                              45/136
  Installing       : python3-rpm-macros-3-45.el8.noarch                                                                                                             46/136
  Installing       : perl-Module-CoreList-tools-1:5.20181130-1.el8.noarch                                                                                           47/136
  Installing       : libSM-1.2.3-1.el8.x86_64                                                                                                                       48/136
  Installing       : libXt-1.1.5-12.el8.x86_64                                                                                                                      49/136
  Installing       : libXmu-1.1.3-1.el8.x86_64                                                                                                                      50/136
  Installing       : libXaw-1.0.13-10.el8.x86_64                                                                                                                    51/136
  Installing       : perl-experimental-0.019-2.el8.noarch                                                                                                           52/136
  Installing       : xterm-resize-331-2.el8.x86_64                                                                                                                  53/136
  Installing       : rust-srpm-macros-5-2.el8.noarch                                                                                                                54/136
  Installing       : qt5-srpm-macros-5.15.3-1.el8.noarch                                                                                                            55/136
  Installing       : perl-utils-5.26.3-423.el8_10.noarch                                                                                                            56/136
  Installing       : perl-srpm-macros-1-25.el8.noarch                                                                                                               57/136
  Installing       : perl-perlfaq-5.20180605-1.el8.noarch                                                                                                           58/136
  Installing       : perl-local-lib-2.000024-2.el8.noarch                                                                                                           59/136
  Installing       : perl-Unicode-Collate-1.25-2.el8.x86_64                                                                                                         60/136
  Installing       : perl-Time-Piece-1.31-423.el8_10.x86_64                                                                                                         61/136
  Installing       : perl-Thread-Queue-3.13-1.el8.noarch                                                                                                            62/136
  Installing       : perl-Text-Template-1.51-1.el8.noarch                                                                                                           63/136
  Installing       : perl-Text-Glob-0.11-4.el8.noarch                                                                                                               64/136
  Installing       : perl-Test-Simple-1:1.302135-1.el8.noarch                                                                                                       65/136
  Installing       : perl-Test-1.30-423.el8_10.noarch                                                                                                               66/136
  Installing       : perl-TermReadKey-2.37-7.el8.x86_64                                                                                                             67/136
  Installing       : perl-Sys-Syslog-0.35-397.el8.x86_64                                                                                                            68/136
  Installing       : perl-Pod-Parser-1.63-396.el8.noarch                                                                                                            69/136
  Installing       : perl-Pod-Checker-4:1.73-395.el8.noarch                                                                                                         70/136
  Installing       : perl-PerlIO-via-QuotedPrint-0.08-395.el8.noarch                                                                                                71/136
  Installing       : perl-Package-Generator-1.106-11.el8.noarch                                                                                                     72/136
  Installing       : perl-Sub-Exporter-0.987-15.el8.noarch                                                                                                          73/136
  Installing       : perl-Module-Loaded-1:0.08-423.el8_10.noarch                                                                                                    74/136
  Installing       : perl-Memoize-1.03-423.el8_10.noarch                                                                                                            75/136
  Installing       : perl-MRO-Compat-0.13-4.el8.noarch                                                                                                              76/136
  Installing       : perl-Data-Section-0.200007-3.el8.noarch                                                                                                        77/136
  Installing       : perl-Software-License-0.103013-2.el8.noarch                                                                                                    78/136
  Installing       : perl-Locale-Codes-3.57-1.el8.noarch                                                                                                            79/136
  Installing       : perl-IPC-SysV-2.07-397.el8.x86_64                                                                                                              80/136
  Installing       : perl-File-Which-1.22-2.el8.noarch                                                                                                              81/136
  Installing       : perl-File-HomeDir-1.002-4.el8.noarch                                                                                                           82/136
  Installing       : perl-ExtUtils-MM-Utils-1:7.34-1.el8.noarch                                                                                                     83/136
  Installing       : perl-IPC-Cmd-2:1.02-1.el8.noarch                                                                                                               84/136
  Installing       : perl-File-Fetch-0.56-2.el8.noarch                                                                                                              85/136
  Installing       : perl-Env-1.04-395.el8.noarch                                                                                                                   86/136
  Installing       : perl-Encode-Locale-1.05-10.0.1.module+el8.3.0+90378+3cefc087.noarch                                                                            87/136
  Installing       : perl-Devel-Size-0.81-2.el8.x86_64                                                                                                              88/136
  Installing       : perl-Devel-Peek-1.26-423.el8_10.x86_64                                                                                                         89/136
  Installing       : perl-Devel-PPPort-3.36-5.el8.x86_64                                                                                                            90/136
  Installing       : perl-DB_File-1.842-1.el8.x86_64                                                                                                                91/136
  Installing       : perl-Config-Perl-V-0.30-1.el8.noarch                                                                                                           92/136
  Installing       : perl-Compress-Bzip2-2.26-6.el8.x86_64                                                                                                          93/136
  Installing       : perl-B-Debug-1.26-2.el8.noarch                                                                                                                 94/136
  Installing       : perl-Attribute-Handlers-0.99-423.el8_10.noarch                                                                                                 95/136
  Installing       : openblas-srpm-macros-2-2.el8.noarch                                                                                                            96/136
  Installing       : ocaml-srpm-macros-5-4.el8.noarch                                                                                                               97/136
  Installing       : libmcpp-2.7.2-20.el8.x86_64                                                                                                                    98/136
  Running scriptlet: libmcpp-2.7.2-20.el8.x86_64                                                                                                                    98/136
  Installing       : mcpp-2.7.2-20.el8.x86_64                                                                                                                       99/136
  Installing       : libfontenc-1.1.3-8.el8.x86_64                                                                                                                 100/136
  Installing       : xorg-x11-font-utils-1:7.5-41.el8.x86_64                                                                                                       101/136
  Installing       : xorg-x11-fonts-misc-7.5-19.el8.noarch                                                                                                         102/136
  Running scriptlet: xorg-x11-fonts-misc-7.5-19.el8.noarch                                                                                                         102/136
  Installing       : libXxf86vm-1.1.4-9.el8.x86_64                                                                                                                 103/136
  Installing       : libXxf86misc-1.0.4-1.el8.x86_64                                                                                                               104/136
  Installing       : libXrandr-1.5.2-1.el8.x86_64                                                                                                                  105/136
  Installing       : libXinerama-1.1.4-1.el8.x86_64                                                                                                                106/136
  Installing       : libXi-1.7.10-1.el8.x86_64                                                                                                                     107/136
  Installing       : libXft-2.3.3-1.el8.x86_64                                                                                                                     108/136
  Installing       : libXfixes-5.0.3-7.el8.x86_64                                                                                                                  109/136
  Installing       : libXcursor-1.1.15-3.el8.x86_64                                                                                                                110/136
  Installing       : go-srpm-macros-2-17.el8.noarch                                                                                                                111/136
  Installing       : ghc-srpm-macros-1.4.2-7.el8.noarch                                                                                                            112/136
  Installing       : gcc-plugin-annobin-8.5.0-28.0.1.el8_10.x86_64                                                                                                 113/136
  Installing       : efi-srpm-macros-3-3.0.1.el8.noarch                                                                                                            114/136
  Installing       : dwz-0.12-10.el8.x86_64                                                                                                                        115/136
  Installing       : annobin-11.13-2.0.6.el8.x86_64                                                                                                                116/136
  Installing       : redhat-rpm-config-131-1.0.1.el8.noarch                                                                                                        117/136
  Running scriptlet: redhat-rpm-config-131-1.0.1.el8.noarch                                                                                                        117/136
  Installing       : perl-Algorithm-Diff-1.1903-9.el8.noarch                                                                                                       118/136
  Installing       : perl-Text-Diff-1.45-2.el8.noarch                                                                                                              119/136
  Installing       : perl-Archive-Tar-2.30-3.el8_10.noarch                                                                                                         120/136
  Downgrading      : dtrace-2.0.1-1.el8.x86_64                                                                                                                     121/136
  Running scriptlet: dtrace-2.0.1-1.el8.x86_64                                                                                                                     121/136
  Installing       : perl-ExtUtils-Install-2.14-4.el8.noarch                                                                                                       122/136
  Installing       : perl-devel-4:5.26.3-423.el8_10.x86_64                                                                                                         123/136
  Installing       : perl-ExtUtils-MakeMaker-1:7.34-1.el8.noarch                                                                                                   124/136
  Installing       : perl-ExtUtils-CBuilder-1:0.280230-2.el8.noarch                                                                                                125/136
  Installing       : perl-ExtUtils-Embed-1.34-423.el8_10.noarch                                                                                                    126/136
  Installing       : perl-ExtUtils-Miniperl-1.06-423.el8_10.noarch                                                                                                 127/136
  Installing       : perl-libnetcfg-4:5.26.3-423.el8_10.noarch                                                                                                     128/136
  Installing       : perl-Encode-devel-4:2.97-3.el8.x86_64                                                                                                         129/136
  Installing       : perl-inc-latest-2:0.500-9.el8.noarch                                                                                                          130/136
  Installing       : perl-Module-Build-2:0.42.24-5.el8.noarch                                                                                                      131/136
  Installing       : perl-CPAN-2.18-402.el8_10.noarch                                                                                                              132/136
  Installing       : perl-4:5.26.3-423.el8_10.x86_64                                                                                                               133/136
  Installing       : xorg-x11-server-utils-7.7-27.el8.x86_64                                                                                                       134/136
  Installing       : xterm-331-2.el8.x86_64                                                                                                                        135/136
  Running scriptlet: dtrace-2.0.7-4.el8.x86_64                                                                                                                     136/136
  Cleanup          : dtrace-2.0.7-4.el8.x86_64                                                                                                                     136/136
  Running scriptlet: dtrace-2.0.7-4.el8.x86_64                                                                                                                     136/136
  Running scriptlet: dtrace-2.0.1-1.el8.x86_64                                                                                                                     136/136
  Running scriptlet: dtrace-2.0.7-4.el8.x86_64                                                                                                                     136/136
  Verifying        : dtrace-2.0.1-1.el8.x86_64                                                                                                                       1/136
  Verifying        : dtrace-2.0.7-4.el8.x86_64                                                                                                                       2/136
  Verifying        : perl-Algorithm-Diff-1.1903-9.el8.noarch                                                                                                         3/136
  Verifying        : perl-Compress-Raw-Bzip2-2.081-1.el8.x86_64                                                                                                      4/136
  Verifying        : perl-Compress-Raw-Zlib-2.081-1.el8.x86_64                                                                                                       5/136
  Verifying        : perl-Math-BigInt-1:1.9998.11-7.el8.noarch                                                                                                       6/136
  Verifying        : perl-Math-Complex-1.59-423.el8_10.noarch                                                                                                        7/136
  Verifying        : perl-Text-Diff-1.45-2.el8.noarch                                                                                                                8/136
  Verifying        : annobin-11.13-2.0.6.el8.x86_64                                                                                                                  9/136
  Verifying        : dwz-0.12-10.el8.x86_64                                                                                                                         10/136
  Verifying        : efi-srpm-macros-3-3.0.1.el8.noarch                                                                                                             11/136
  Verifying        : gcc-plugin-annobin-8.5.0-28.0.1.el8_10.x86_64                                                                                                  12/136
  Verifying        : ghc-srpm-macros-1.4.2-7.el8.noarch                                                                                                             13/136
  Verifying        : go-srpm-macros-2-17.el8.noarch                                                                                                                 14/136
  Verifying        : libICE-1.0.9-15.el8.x86_64                                                                                                                     15/136
  Verifying        : libSM-1.2.3-1.el8.x86_64                                                                                                                       16/136
  Verifying        : libXaw-1.0.13-10.el8.x86_64                                                                                                                    17/136
  Verifying        : libXcursor-1.1.15-3.el8.x86_64                                                                                                                 18/136
  Verifying        : libXfixes-5.0.3-7.el8.x86_64                                                                                                                   19/136
  Verifying        : libXft-2.3.3-1.el8.x86_64                                                                                                                      20/136
  Verifying        : libXi-1.7.10-1.el8.x86_64                                                                                                                      21/136
  Verifying        : libXinerama-1.1.4-1.el8.x86_64                                                                                                                 22/136
  Verifying        : libXmu-1.1.3-1.el8.x86_64                                                                                                                      23/136
  Verifying        : libXpm-3.5.12-11.el8.x86_64                                                                                                                    24/136
  Verifying        : libXrandr-1.5.2-1.el8.x86_64                                                                                                                   25/136
  Verifying        : libXt-1.1.5-12.el8.x86_64                                                                                                                      26/136
  Verifying        : libXxf86misc-1.0.4-1.el8.x86_64                                                                                                                27/136
  Verifying        : libXxf86vm-1.1.4-9.el8.x86_64                                                                                                                  28/136
  Verifying        : libfontenc-1.1.3-8.el8.x86_64                                                                                                                  29/136
  Verifying        : libmcpp-2.7.2-20.el8.x86_64                                                                                                                    30/136
  Verifying        : mcpp-2.7.2-20.el8.x86_64                                                                                                                       31/136
  Verifying        : ocaml-srpm-macros-5-4.el8.noarch                                                                                                               32/136
  Verifying        : openblas-srpm-macros-2-2.el8.noarch                                                                                                            33/136
  Verifying        : perl-4:5.26.3-423.el8_10.x86_64                                                                                                                34/136
  Verifying        : perl-Archive-Tar-2.30-3.el8_10.noarch                                                                                                          35/136
  Verifying        : perl-Archive-Zip-1.60-3.el8.noarch                                                                                                             36/136
  Verifying        : perl-Attribute-Handlers-0.99-423.el8_10.noarch                                                                                                 37/136
  Verifying        : perl-B-Debug-1.26-2.el8.noarch                                                                                                                 38/136
  Verifying        : perl-CPAN-2.18-402.el8_10.noarch                                                                                                               39/136
  Verifying        : perl-CPAN-Meta-2.150010-396.el8.noarch                                                                                                         40/136
  Verifying        : perl-CPAN-Meta-Requirements-2.140-396.el8.noarch                                                                                               41/136
  Verifying        : perl-CPAN-Meta-YAML-0.018-397.el8.noarch                                                                                                       42/136
  Verifying        : perl-Compress-Bzip2-2.26-6.el8.x86_64                                                                                                          43/136
  Verifying        : perl-Config-Perl-V-0.30-1.el8.noarch                                                                                                           44/136
  Verifying        : perl-DB_File-1.842-1.el8.x86_64                                                                                                                45/136
  Verifying        : perl-Data-OptList-0.110-6.el8.noarch                                                                                                           46/136
  Verifying        : perl-Data-Section-0.200007-3.el8.noarch                                                                                                        47/136
  Verifying        : perl-Devel-PPPort-3.36-5.el8.x86_64                                                                                                            48/136
  Verifying        : perl-Devel-Peek-1.26-423.el8_10.x86_64                                                                                                         49/136
  Verifying        : perl-Devel-SelfStubber-1.06-423.el8_10.noarch                                                                                                  50/136
  Verifying        : perl-Devel-Size-0.81-2.el8.x86_64                                                                                                              51/136
  Verifying        : perl-Digest-SHA-1:6.02-1.el8.x86_64                                                                                                            52/136
  Verifying        : perl-Encode-Locale-1.05-10.0.1.module+el8.3.0+90378+3cefc087.noarch                                                                            53/136
  Verifying        : perl-Encode-devel-4:2.97-3.el8.x86_64                                                                                                          54/136
  Verifying        : perl-Env-1.04-395.el8.noarch                                                                                                                   55/136
  Verifying        : perl-ExtUtils-CBuilder-1:0.280230-2.el8.noarch                                                                                                 56/136
  Verifying        : perl-ExtUtils-Command-1:7.34-1.el8.noarch                                                                                                      57/136
  Verifying        : perl-ExtUtils-Embed-1.34-423.el8_10.noarch                                                                                                     58/136
  Verifying        : perl-ExtUtils-Install-2.14-4.el8.noarch                                                                                                        59/136
  Verifying        : perl-ExtUtils-MM-Utils-1:7.34-1.el8.noarch                                                                                                     60/136
  Verifying        : perl-ExtUtils-MakeMaker-1:7.34-1.el8.noarch                                                                                                    61/136
  Verifying        : perl-ExtUtils-Manifest-1.70-395.el8.noarch                                                                                                     62/136
  Verifying        : perl-ExtUtils-Miniperl-1.06-423.el8_10.noarch                                                                                                  63/136
  Verifying        : perl-ExtUtils-ParseXS-1:3.35-2.el8.noarch                                                                                                      64/136
  Verifying        : perl-File-Fetch-0.56-2.el8.noarch                                                                                                              65/136
  Verifying        : perl-File-HomeDir-1.002-4.el8.noarch                                                                                                           66/136
  Verifying        : perl-File-Which-1.22-2.el8.noarch                                                                                                              67/136
  Verifying        : perl-Filter-2:1.58-2.el8.x86_64                                                                                                                68/136
  Verifying        : perl-Filter-Simple-0.94-2.el8.noarch                                                                                                           69/136
  Verifying        : perl-IO-Compress-2.081-2.el8_10.noarch                                                                                                         70/136
  Verifying        : perl-IO-Zlib-1:1.10-423.el8_10.noarch                                                                                                          71/136
  Verifying        : perl-IPC-Cmd-2:1.02-1.el8.noarch                                                                                                               72/136
  Verifying        : perl-IPC-SysV-2.07-397.el8.x86_64                                                                                                              73/136
  Verifying        : perl-JSON-PP-1:2.97.001-3.el8.noarch                                                                                                           74/136
  Verifying        : perl-Locale-Codes-3.57-1.el8.noarch                                                                                                            75/136
  Verifying        : perl-Locale-Maketext-1.28-396.el8.noarch                                                                                                       76/136
  Verifying        : perl-Locale-Maketext-Simple-1:0.21-423.el8_10.noarch                                                                                           77/136
  Verifying        : perl-MRO-Compat-0.13-4.el8.noarch                                                                                                              78/136
  Verifying        : perl-Math-BigInt-FastCalc-0.500.600-6.el8.x86_64                                                                                               79/136
  Verifying        : perl-Math-BigRat-0.2614-1.el8.noarch                                                                                                           80/136
  Verifying        : perl-Memoize-1.03-423.el8_10.noarch                                                                                                            81/136
  Verifying        : perl-Module-Build-2:0.42.24-5.el8.noarch                                                                                                       82/136
  Verifying        : perl-Module-CoreList-1:5.20181130-1.el8.noarch                                                                                                 83/136
  Verifying        : perl-Module-CoreList-tools-1:5.20181130-1.el8.noarch                                                                                           84/136
  Verifying        : perl-Module-Load-1:0.32-395.el8.noarch                                                                                                         85/136
  Verifying        : perl-Module-Load-Conditional-0.68-395.el8.noarch                                                                                               86/136
  Verifying        : perl-Module-Loaded-1:0.08-423.el8_10.noarch                                                                                                    87/136
  Verifying        : perl-Module-Metadata-1.000033-395.el8.noarch                                                                                                   88/136
  Verifying        : perl-Net-Ping-2.55-423.el8_10.noarch                                                                                                           89/136
  Verifying        : perl-Package-Generator-1.106-11.el8.noarch                                                                                                     90/136
  Verifying        : perl-Params-Check-1:0.38-395.el8.noarch                                                                                                        91/136
  Verifying        : perl-Params-Util-1.07-22.el8.x86_64                                                                                                            92/136
  Verifying        : perl-Perl-OSType-1.010-396.el8.noarch                                                                                                          93/136
  Verifying        : perl-PerlIO-via-QuotedPrint-0.08-395.el8.noarch                                                                                                94/136
  Verifying        : perl-Pod-Checker-4:1.73-395.el8.noarch                                                                                                         95/136
  Verifying        : perl-Pod-Html-1.22.02-423.el8_10.noarch                                                                                                        96/136
  Verifying        : perl-Pod-Parser-1.63-396.el8.noarch                                                                                                            97/136
  Verifying        : perl-SelfLoader-1.23-423.el8_10.noarch                                                                                                         98/136
  Verifying        : perl-Software-License-0.103013-2.el8.noarch                                                                                                    99/136
  Verifying        : perl-Sub-Exporter-0.987-15.el8.noarch                                                                                                         100/136
  Verifying        : perl-Sub-Install-0.928-14.el8.noarch                                                                                                          101/136
  Verifying        : perl-Sys-Syslog-0.35-397.el8.x86_64                                                                                                           102/136
  Verifying        : perl-TermReadKey-2.37-7.el8.x86_64                                                                                                            103/136
  Verifying        : perl-Test-1.30-423.el8_10.noarch                                                                                                              104/136
  Verifying        : perl-Test-Harness-1:3.42-1.el8.noarch                                                                                                         105/136
  Verifying        : perl-Test-Simple-1:1.302135-1.el8.noarch                                                                                                      106/136
  Verifying        : perl-Text-Balanced-2.03-395.el8.noarch                                                                                                        107/136
  Verifying        : perl-Text-Glob-0.11-4.el8.noarch                                                                                                              108/136
  Verifying        : perl-Text-Template-1.51-1.el8.noarch                                                                                                          109/136
  Verifying        : perl-Thread-Queue-3.13-1.el8.noarch                                                                                                           110/136
  Verifying        : perl-Time-HiRes-4:1.9758-2.el8.x86_64                                                                                                         111/136
  Verifying        : perl-Time-Piece-1.31-423.el8_10.x86_64                                                                                                        112/136
  Verifying        : perl-Unicode-Collate-1.25-2.el8.x86_64                                                                                                        113/136
  Verifying        : perl-bignum-0.49-2.el8.noarch                                                                                                                 114/136
  Verifying        : perl-devel-4:5.26.3-423.el8_10.x86_64                                                                                                         115/136
  Verifying        : perl-encoding-4:2.22-3.el8.x86_64                                                                                                             116/136
  Verifying        : perl-experimental-0.019-2.el8.noarch                                                                                                          117/136
  Verifying        : perl-inc-latest-2:0.500-9.el8.noarch                                                                                                          118/136
  Verifying        : perl-libnetcfg-4:5.26.3-423.el8_10.noarch                                                                                                     119/136
  Verifying        : perl-local-lib-2.000024-2.el8.noarch                                                                                                          120/136
  Verifying        : perl-open-1.11-423.el8_10.noarch                                                                                                              121/136
  Verifying        : perl-perlfaq-5.20180605-1.el8.noarch                                                                                                          122/136
  Verifying        : perl-srpm-macros-1-25.el8.noarch                                                                                                              123/136
  Verifying        : perl-utils-5.26.3-423.el8_10.noarch                                                                                                           124/136
  Verifying        : perl-version-6:0.99.24-1.el8.x86_64                                                                                                           125/136
  Verifying        : python-rpm-macros-3-45.el8.noarch                                                                                                             126/136
  Verifying        : python-srpm-macros-3-45.el8.noarch                                                                                                            127/136
  Verifying        : python3-rpm-macros-3-45.el8.noarch                                                                                                            128/136
  Verifying        : qt5-srpm-macros-5.15.3-1.el8.noarch                                                                                                           129/136
  Verifying        : redhat-rpm-config-131-1.0.1.el8.noarch                                                                                                        130/136
  Verifying        : rust-srpm-macros-5-2.el8.noarch                                                                                                               131/136
  Verifying        : xorg-x11-font-utils-1:7.5-41.el8.x86_64                                                                                                       132/136
  Verifying        : xorg-x11-fonts-misc-7.5-19.el8.noarch                                                                                                         133/136
  Verifying        : xorg-x11-server-utils-7.7-27.el8.x86_64                                                                                                       134/136
  Verifying        : xterm-331-2.el8.x86_64                                                                                                                        135/136
  Verifying        : xterm-resize-331-2.el8.x86_64                                                                                                                 136/136

Downgraded:
  dtrace-2.0.1-1.el8.x86_64
Installed:
  annobin-11.13-2.0.6.el8.x86_64                    dwz-0.12-10.el8.x86_64                            efi-srpm-macros-3-3.0.1.el8.noarch
  gcc-plugin-annobin-8.5.0-28.0.1.el8_10.x86_64     ghc-srpm-macros-1.4.2-7.el8.noarch                go-srpm-macros-2-17.el8.noarch
  libICE-1.0.9-15.el8.x86_64                        libSM-1.2.3-1.el8.x86_64                          libXaw-1.0.13-10.el8.x86_64
  libXcursor-1.1.15-3.el8.x86_64                    libXfixes-5.0.3-7.el8.x86_64                      libXft-2.3.3-1.el8.x86_64
  libXi-1.7.10-1.el8.x86_64                         libXinerama-1.1.4-1.el8.x86_64                    libXmu-1.1.3-1.el8.x86_64
  libXpm-3.5.12-11.el8.x86_64                       libXrandr-1.5.2-1.el8.x86_64                      libXt-1.1.5-12.el8.x86_64
  libXxf86misc-1.0.4-1.el8.x86_64                   libXxf86vm-1.1.4-9.el8.x86_64                     libfontenc-1.1.3-8.el8.x86_64
  libmcpp-2.7.2-20.el8.x86_64                       mcpp-2.7.2-20.el8.x86_64                          ocaml-srpm-macros-5-4.el8.noarch
  openblas-srpm-macros-2-2.el8.noarch               perl-4:5.26.3-423.el8_10.x86_64                   perl-Algorithm-Diff-1.1903-9.el8.noarch
  perl-Archive-Tar-2.30-3.el8_10.noarch             perl-Archive-Zip-1.60-3.el8.noarch                perl-Attribute-Handlers-0.99-423.el8_10.noarch
  perl-B-Debug-1.26-2.el8.noarch                    perl-CPAN-2.18-402.el8_10.noarch                  perl-CPAN-Meta-2.150010-396.el8.noarch
  perl-CPAN-Meta-Requirements-2.140-396.el8.noarch  perl-CPAN-Meta-YAML-0.018-397.el8.noarch          perl-Compress-Bzip2-2.26-6.el8.x86_64
  perl-Compress-Raw-Bzip2-2.081-1.el8.x86_64        perl-Compress-Raw-Zlib-2.081-1.el8.x86_64         perl-Config-Perl-V-0.30-1.el8.noarch
  perl-DB_File-1.842-1.el8.x86_64                   perl-Data-OptList-0.110-6.el8.noarch              perl-Data-Section-0.200007-3.el8.noarch
  perl-Devel-PPPort-3.36-5.el8.x86_64               perl-Devel-Peek-1.26-423.el8_10.x86_64            perl-Devel-SelfStubber-1.06-423.el8_10.noarch
  perl-Devel-Size-0.81-2.el8.x86_64                 perl-Digest-SHA-1:6.02-1.el8.x86_64               perl-Encode-Locale-1.05-10.0.1.module+el8.3.0+90378+3cefc087.noarch
  perl-Encode-devel-4:2.97-3.el8.x86_64             perl-Env-1.04-395.el8.noarch                      perl-ExtUtils-CBuilder-1:0.280230-2.el8.noarch
  perl-ExtUtils-Command-1:7.34-1.el8.noarch         perl-ExtUtils-Embed-1.34-423.el8_10.noarch        perl-ExtUtils-Install-2.14-4.el8.noarch
  perl-ExtUtils-MM-Utils-1:7.34-1.el8.noarch        perl-ExtUtils-MakeMaker-1:7.34-1.el8.noarch       perl-ExtUtils-Manifest-1.70-395.el8.noarch
  perl-ExtUtils-Miniperl-1.06-423.el8_10.noarch     perl-ExtUtils-ParseXS-1:3.35-2.el8.noarch         perl-File-Fetch-0.56-2.el8.noarch
  perl-File-HomeDir-1.002-4.el8.noarch              perl-File-Which-1.22-2.el8.noarch                 perl-Filter-2:1.58-2.el8.x86_64
  perl-Filter-Simple-0.94-2.el8.noarch              perl-IO-Compress-2.081-2.el8_10.noarch            perl-IO-Zlib-1:1.10-423.el8_10.noarch
  perl-IPC-Cmd-2:1.02-1.el8.noarch                  perl-IPC-SysV-2.07-397.el8.x86_64                 perl-JSON-PP-1:2.97.001-3.el8.noarch
  perl-Locale-Codes-3.57-1.el8.noarch               perl-Locale-Maketext-1.28-396.el8.noarch          perl-Locale-Maketext-Simple-1:0.21-423.el8_10.noarch
  perl-MRO-Compat-0.13-4.el8.noarch                 perl-Math-BigInt-1:1.9998.11-7.el8.noarch         perl-Math-BigInt-FastCalc-0.500.600-6.el8.x86_64
  perl-Math-BigRat-0.2614-1.el8.noarch              perl-Math-Complex-1.59-423.el8_10.noarch          perl-Memoize-1.03-423.el8_10.noarch
  perl-Module-Build-2:0.42.24-5.el8.noarch          perl-Module-CoreList-1:5.20181130-1.el8.noarch    perl-Module-CoreList-tools-1:5.20181130-1.el8.noarch
  perl-Module-Load-1:0.32-395.el8.noarch            perl-Module-Load-Conditional-0.68-395.el8.noarch  perl-Module-Loaded-1:0.08-423.el8_10.noarch
  perl-Module-Metadata-1.000033-395.el8.noarch      perl-Net-Ping-2.55-423.el8_10.noarch              perl-Package-Generator-1.106-11.el8.noarch
  perl-Params-Check-1:0.38-395.el8.noarch           perl-Params-Util-1.07-22.el8.x86_64               perl-Perl-OSType-1.010-396.el8.noarch
  perl-PerlIO-via-QuotedPrint-0.08-395.el8.noarch   perl-Pod-Checker-4:1.73-395.el8.noarch            perl-Pod-Html-1.22.02-423.el8_10.noarch
  perl-Pod-Parser-1.63-396.el8.noarch               perl-SelfLoader-1.23-423.el8_10.noarch            perl-Software-License-0.103013-2.el8.noarch
  perl-Sub-Exporter-0.987-15.el8.noarch             perl-Sub-Install-0.928-14.el8.noarch              perl-Sys-Syslog-0.35-397.el8.x86_64
  perl-TermReadKey-2.37-7.el8.x86_64                perl-Test-1.30-423.el8_10.noarch                  perl-Test-Harness-1:3.42-1.el8.noarch
  perl-Test-Simple-1:1.302135-1.el8.noarch          perl-Text-Balanced-2.03-395.el8.noarch            perl-Text-Diff-1.45-2.el8.noarch
  perl-Text-Glob-0.11-4.el8.noarch                  perl-Text-Template-1.51-1.el8.noarch              perl-Thread-Queue-3.13-1.el8.noarch
  perl-Time-HiRes-4:1.9758-2.el8.x86_64             perl-Time-Piece-1.31-423.el8_10.x86_64            perl-Unicode-Collate-1.25-2.el8.x86_64
  perl-bignum-0.49-2.el8.noarch                     perl-devel-4:5.26.3-423.el8_10.x86_64             perl-encoding-4:2.22-3.el8.x86_64
  perl-experimental-0.019-2.el8.noarch              perl-inc-latest-2:0.500-9.el8.noarch              perl-libnetcfg-4:5.26.3-423.el8_10.noarch
  perl-local-lib-2.000024-2.el8.noarch              perl-open-1.11-423.el8_10.noarch                  perl-perlfaq-5.20180605-1.el8.noarch
  perl-srpm-macros-1-25.el8.noarch                  perl-utils-5.26.3-423.el8_10.noarch               perl-version-6:0.99.24-1.el8.x86_64
  python-rpm-macros-3-45.el8.noarch                 python-srpm-macros-3-45.el8.noarch                python3-rpm-macros-3-45.el8.noarch
  qt5-srpm-macros-5.15.3-1.el8.noarch               redhat-rpm-config-131-1.0.1.el8.noarch            rust-srpm-macros-5-2.el8.noarch
  xorg-x11-font-utils-1:7.5-41.el8.x86_64           xorg-x11-fonts-misc-7.5-19.el8.noarch             xorg-x11-server-utils-7.7-27.el8.x86_64
  xterm-331-2.el8.x86_64                            xterm-resize-331-2.el8.x86_64

Complete!

#Install latest asmlib3.1 package
[root@caoradb02 software]# dnf localinstall -y oracleasmlib-3.1.3-1.el8.x86_64.rpm
Last metadata expiration check: 0:04:36 ago on Sat 22 Aug 2026 06:34:03 AM GMT.
Dependencies resolved.
===========================================================================================================================================================================
 Package                                       Architecture                       Version                                   Repository                                Size
===========================================================================================================================================================================
Installing:
 oracleasmlib                                  x86_64                             3.1.3-1.el8                               @commandline                              52 k
Installing dependencies:
 oracleasm-support                             x86_64                             3.1.1-5.el8                               ol8_addons                                87 k

Transaction Summary
===========================================================================================================================================================================
Install  2 Packages

Total size: 139 k
Total download size: 87 k
Installed size: 414 k
Downloading Packages:
oracleasm-support-3.1.1-5.el8.x86_64.rpm                                                                                                   3.0 MB/s |  87 kB     00:00
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                                      2.8 MB/s |  87 kB     00:00
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                                   1/1
  Installing       : oracleasm-support-3.1.1-5.el8.x86_64                                                                                                              1/2
  Running scriptlet: oracleasm-support-3.1.1-5.el8.x86_64                                                                                                              1/2
Created symlink /etc/systemd/system/multi-user.target.wants/oracleasm.service → /usr/lib/systemd/system/oracleasm.service.

  Installing       : oracleasmlib-3.1.3-1.el8.x86_64                                                                                                                   2/2
  Running scriptlet: oracleasmlib-3.1.3-1.el8.x86_64                                                                                                                   2/2
  Verifying        : oracleasm-support-3.1.1-5.el8.x86_64                                                                                                              1/2
  Verifying        : oracleasmlib-3.1.3-1.el8.x86_64                                                                                                                   2/2

Installed:
  oracleasm-support-3.1.1-5.el8.x86_64                                                   oracleasmlib-3.1.3-1.el8.x86_64

Complete!

[root@caoradb02 ~]# dnf install kmod-oracleasm
Last metadata expiration check: 0:02:02 ago on Sat 22 Aug 2026 06:34:03 AM GMT.
Dependencies resolved.
===========================================================================================================================================================================
 Package                                      Architecture                  Version                                         Repository                                Size
===========================================================================================================================================================================
Installing:
 kmod-redhat-oracleasm                        x86_64                        8:2.0.8-18.2.0.1.el8_10                         ol8_baseos_latest                         45 k

Transaction Summary
===========================================================================================================================================================================
Install  1 Package

Total download size: 45 k
Installed size: 143 k
Is this ok [y/N]: y
Downloading Packages:
kmod-redhat-oracleasm-2.0.8-18.2.0.1.el8_10.x86_64.rpm                                                                                     1.5 MB/s |  45 kB     00:00
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                                      1.4 MB/s |  45 kB     00:00
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                                   1/1
  Installing       : kmod-redhat-oracleasm-8:2.0.8-18.2.0.1.el8_10.x86_64                                                                                              1/1
  Running scriptlet: kmod-redhat-oracleasm-8:2.0.8-18.2.0.1.el8_10.x86_64                                                                                              1/1
  Verifying        : kmod-redhat-oracleasm-8:2.0.8-18.2.0.1.el8_10.x86_64                                                                                              1/1

Installed:
  kmod-redhat-oracleasm-8:2.0.8-18.2.0.1.el8_10.x86_64

Complete!


#Install oracle-database-preinstall-19c package which will perform all the pre-requisites for the install.
[root@caoradb02 software]# dnf install -y oracle-database-preinstall-19c
Last metadata expiration check: 0:00:36 ago on Sat 22 Aug 2026 06:38:48 AM GMT.
Dependencies resolved.
===========================================================================================================================================================================
 Package                                             Architecture                Version                                      Repository                              Size
===========================================================================================================================================================================
Installing:
 oracle-database-preinstall-19c                      x86_64                      1.0-4.el8                                    ol8_appstream                           30 k
Installing dependencies:
 ksh                                                 x86_64                      20120801-271.0.1.el8_10                      ol8_appstream                          924 k
 libX11-xcb                                          x86_64                      1.6.8-9.el8_10                               ol8_appstream                           14 k
 libXcomposite                                       x86_64                      0.4.4-14.el8                                 ol8_appstream                           28 k
 libXtst                                             x86_64                      1.2.3-7.el8                                  ol8_appstream                           22 k
 libXv                                               x86_64                      1.0.11-7.el8                                 ol8_appstream                           20 k
 libXxf86dga                                         x86_64                      1.1.5-1.el8                                  ol8_appstream                           26 k
 libaio-devel                                        x86_64                      0.3.112-1.el8                                ol8_baseos_latest                       19 k
 libdmx                                              x86_64                      1.1.4-4.el8_10                               ol8_appstream                           21 k
 libnsl                                              x86_64                      2.28-251.0.5.el8_10.40                       ol8_baseos_latest                      120 k
 libstdc++-devel                                     x86_64                      8.5.0-28.0.1.el8_10                          ol8_appstream                          2.1 M
 xorg-x11-utils                                      x86_64                      7.5-28.el8                                   ol8_appstream                          136 k
 xorg-x11-xauth                                      x86_64                      1:1.0.9-12.el8                               ol8_appstream                           39 k

Transaction Summary
===========================================================================================================================================================================
Install  13 Packages

Total download size: 3.4 M
Installed size: 15 M
Downloading Packages:
(1/13): libnsl-2.28-251.0.5.el8_10.40.x86_64.rpm                                                                                           2.7 MB/s | 120 kB     00:00
(2/13): libaio-devel-0.3.112-1.el8.x86_64.rpm                                                                                              398 kB/s |  19 kB     00:00
(3/13): libX11-xcb-1.6.8-9.el8_10.x86_64.rpm                                                                                               2.2 MB/s |  14 kB     00:00
(4/13): libXtst-1.2.3-7.el8.x86_64.rpm                                                                                                     2.5 MB/s |  22 kB     00:00
(5/13): ksh-20120801-271.0.1.el8_10.x86_64.rpm                                                                                              14 MB/s | 924 kB     00:00
(6/13): libXcomposite-0.4.4-14.el8.x86_64.rpm                                                                                              1.3 MB/s |  28 kB     00:00
(7/13): libXv-1.0.11-7.el8.x86_64.rpm                                                                                                      1.6 MB/s |  20 kB     00:00
(8/13): libdmx-1.1.4-4.el8_10.x86_64.rpm                                                                                                   2.3 MB/s |  21 kB     00:00
(9/13): libXxf86dga-1.1.5-1.el8.x86_64.rpm                                                                                                 2.2 MB/s |  26 kB     00:00
(10/13): oracle-database-preinstall-19c-1.0-4.el8.x86_64.rpm                                                                               4.4 MB/s |  30 kB     00:00
(11/13): xorg-x11-utils-7.5-28.el8.x86_64.rpm                                                                                               14 MB/s | 136 kB     00:00
(12/13): xorg-x11-xauth-1.0.9-12.el8.x86_64.rpm                                                                                            5.2 MB/s |  39 kB     00:00
(13/13): libstdc++-devel-8.5.0-28.0.1.el8_10.x86_64.rpm                                                                                     14 MB/s | 2.1 MB     00:00
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                                       15 MB/s | 3.4 MB     00:00
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                                   1/1
  Installing       : xorg-x11-xauth-1:1.0.9-12.el8.x86_64                                                                                                             1/13
  Installing       : libstdc++-devel-8.5.0-28.0.1.el8_10.x86_64                                                                                                       2/13
  Installing       : libdmx-1.1.4-4.el8_10.x86_64                                                                                                                     3/13
  Installing       : libXxf86dga-1.1.5-1.el8.x86_64                                                                                                                   4/13
  Installing       : libXv-1.0.11-7.el8.x86_64                                                                                                                        5/13
  Installing       : libXtst-1.2.3-7.el8.x86_64                                                                                                                       6/13
  Installing       : libXcomposite-0.4.4-14.el8.x86_64                                                                                                                7/13
  Installing       : libX11-xcb-1.6.8-9.el8_10.x86_64                                                                                                                 8/13
  Installing       : xorg-x11-utils-7.5-28.el8.x86_64                                                                                                                 9/13
  Installing       : ksh-20120801-271.0.1.el8_10.x86_64                                                                                                              10/13
  Running scriptlet: ksh-20120801-271.0.1.el8_10.x86_64                                                                                                              10/13
  Installing       : libnsl-2.28-251.0.5.el8_10.40.x86_64                                                                                                            11/13
  Installing       : libaio-devel-0.3.112-1.el8.x86_64                                                                                                               12/13
  Running scriptlet: oracle-database-preinstall-19c-1.0-4.el8.x86_64                                                                                                 13/13
  Installing       : oracle-database-preinstall-19c-1.0-4.el8.x86_64                                                                                                 13/13
  Running scriptlet: oracle-database-preinstall-19c-1.0-4.el8.x86_64                                                                                                 13/13
  Verifying        : libaio-devel-0.3.112-1.el8.x86_64                                                                                                                1/13
  Verifying        : libnsl-2.28-251.0.5.el8_10.40.x86_64                                                                                                             2/13
  Verifying        : ksh-20120801-271.0.1.el8_10.x86_64                                                                                                               3/13
  Verifying        : libX11-xcb-1.6.8-9.el8_10.x86_64                                                                                                                 4/13
  Verifying        : libXcomposite-0.4.4-14.el8.x86_64                                                                                                                5/13
  Verifying        : libXtst-1.2.3-7.el8.x86_64                                                                                                                       6/13
  Verifying        : libXv-1.0.11-7.el8.x86_64                                                                                                                        7/13
  Verifying        : libXxf86dga-1.1.5-1.el8.x86_64                                                                                                                   8/13
  Verifying        : libdmx-1.1.4-4.el8_10.x86_64                                                                                                                     9/13
  Verifying        : libstdc++-devel-8.5.0-28.0.1.el8_10.x86_64                                                                                                      10/13
  Verifying        : oracle-database-preinstall-19c-1.0-4.el8.x86_64                                                                                                 11/13
  Verifying        : xorg-x11-utils-7.5-28.el8.x86_64                                                                                                                12/13
  Verifying        : xorg-x11-xauth-1:1.0.9-12.el8.x86_64                                                                                                            13/13

Installed:
  ksh-20120801-271.0.1.el8_10.x86_64     libX11-xcb-1.6.8-9.el8_10.x86_64             libXcomposite-0.4.4-14.el8.x86_64                 libXtst-1.2.3-7.el8.x86_64
  libXv-1.0.11-7.el8.x86_64              libXxf86dga-1.1.5-1.el8.x86_64               libaio-devel-0.3.112-1.el8.x86_64                 libdmx-1.1.4-4.el8_10.x86_64
  libnsl-2.28-251.0.5.el8_10.40.x86_64   libstdc++-devel-8.5.0-28.0.1.el8_10.x86_64   oracle-database-preinstall-19c-1.0-4.el8.x86_64   xorg-x11-utils-7.5-28.el8.x86_64
  xorg-x11-xauth-1:1.0.9-12.el8.x86_64

Complete!

[root@caoradb02 software]# cd /u01/app/19.3.0/grid/cv/rpm/
[root@caoradb02 rpm]# CVUQDISK_GRP=oinstall; export CVUQDISK_GRP
[root@caoradb02 rpm]# dnf install cvuqdisk-1.0.10-1.rpm
Last metadata expiration check: 0:01:20 ago on Sat 22 Aug 2026 06:38:48 AM GMT.
Dependencies resolved.
===========================================================================================================================================================================
 Package                                 Architecture                          Version                                   Repository                                   Size
===========================================================================================================================================================================
Installing:
 cvuqdisk                                x86_64                                1.0.10-1                                  @commandline                                 11 k

Transaction Summary
===========================================================================================================================================================================
Install  1 Package

Total size: 11 k
Installed size: 22 k
Is this ok [y/N]: y
Downloading Packages:
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                                   1/1
  Running scriptlet: cvuqdisk-1.0.10-1.x86_64                                                                                                                          1/1
  Installing       : cvuqdisk-1.0.10-1.x86_64                                                                                                                          1/1
  Running scriptlet: cvuqdisk-1.0.10-1.x86_64                                                                                                                          1/1
  Verifying        : cvuqdisk-1.0.10-1.x86_64                                                                                                                          1/1

Installed:
  cvuqdisk-1.0.10-1.x86_64

Complete!

#Update all packages
[root@caoradb02 rpm]# dnf update -y
Last metadata expiration check: 0:01:43 ago on Sat 22 Aug 2026 06:38:48 AM GMT.
Dependencies resolved.
===========================================================================================================================================================================
 Package                                   Architecture                Version                                                Repository                              Size
===========================================================================================================================================================================
Installing:
 kernel                                    x86_64                      4.18.0-553.156.1.el8_10                                ol8_baseos_latest                       11 M
 kernel-core                               x86_64                      4.18.0-553.156.1.el8_10                                ol8_baseos_latest                       44 M
 kernel-devel                              x86_64                      4.18.0-553.156.1.el8_10                                ol8_baseos_latest                       24 M
 kernel-modules                            x86_64                      4.18.0-553.156.1.el8_10                                ol8_baseos_latest                       36 M
 kernel-uek                                x86_64                      5.15.0-323.211.3.4.el8uek                              ol8_UEKR7                              3.6 M
 kernel-uek-core                           x86_64                      5.15.0-323.211.3.4.el8uek                              ol8_UEKR7                               64 M
 kernel-uek-devel                          x86_64                      5.15.0-323.211.3.4.el8uek                              ol8_UEKR7                               22 M
 kernel-uek-modules                        x86_64                      5.15.0-323.211.3.4.el8uek                              ol8_UEKR7                               74 M
Upgrading:
 attr                                      x86_64                      2.6.0-1.el8_10                                         ol8_baseos_latest                       72 k
 bind-export-libs                          x86_64                      32:9.11.36-16.el8_10.14                                ol8_baseos_latest                      1.1 M
 bind-libs                                 x86_64                      32:9.11.36-16.el8_10.14                                ol8_appstream                          177 k
 bind-libs-lite                            x86_64                      32:9.11.36-16.el8_10.14                                ol8_appstream                          1.2 M
 bind-license                              noarch                      32:9.11.36-16.el8_10.14                                ol8_appstream                          106 k
 bind-utils                                x86_64                      32:9.11.36-16.el8_10.14                                ol8_appstream                          454 k
 bpftool                                   x86_64                      5.15.0-323.211.3.4.el8uek                              ol8_UEKR7                              4.4 M
 curl                                      x86_64                      7.61.1-34.el8_10.13                                    ol8_baseos_latest                      354 k
 dracut                                    x86_64                      049-246.git20260728.0.1.el8_10                         ol8_baseos_latest                      383 k
 dracut-config-rescue                      x86_64                      049-246.git20260728.0.1.el8_10                         ol8_baseos_latest                       66 k
 dracut-network                            x86_64                      049-246.git20260728.0.1.el8_10                         ol8_baseos_latest                      115 k
 dracut-squash                             x86_64                      049-246.git20260728.0.1.el8_10                         ol8_baseos_latest                       66 k
 dtrace                                    x86_64                      2.0.7-4.el8                                            ol8_UEKR7                              4.8 M
 firewalld                                 noarch                      0.9.11-12.0.1.el8_10                                   ol8_baseos_latest                      510 k
 firewalld-filesystem                      noarch                      0.9.11-12.0.1.el8_10                                   ol8_baseos_latest                       78 k
 isns-utils-libs                           x86_64                      0.99-1.el8_10.1                                        ol8_baseos_latest                      103 k
 kernel-headers                            x86_64                      4.18.0-553.156.1.el8_10                                ol8_baseos_latest                       12 M
 kernel-tools                              x86_64                      4.18.0-553.156.1.el8_10                                ol8_baseos_latest                       11 M
 kernel-tools-libs                         x86_64                      4.18.0-553.156.1.el8_10                                ol8_baseos_latest                       11 M
 ksplice                                   x86_64                      2.1.6-1.el8                                            ol8_ksplice                            523 k
     replacing  ksplice-core0.x86_64 2.1.2-1.el8
     replacing  ksplice-tools.x86_64 2.1.2-1.el8
 libattr                                   x86_64                      2.6.0-1.el8_10                                         ol8_baseos_latest                       26 k
 libcurl                                   x86_64                      7.61.1-34.el8_10.13                                    ol8_baseos_latest                      307 k
 libnghttp2                                x86_64                      1.33.0-6.el8_10.3                                      ol8_baseos_latest                       77 k
 libxmlb                                   x86_64                      0.3.28-2.el8_10                                        ol8_baseos_latest                      109 k
 microcode_ctl                             x86_64                      4:20260512-1.0.1.el8_10                                ol8_baseos_latest                       17 M
 nftables                                  x86_64                      1:1.0.4-8.el8_10                                       ol8_baseos_latest                      381 k
 pam                                       x86_64                      1.3.1-40.0.1.el8_10                                    ol8_baseos_latest                      749 k
 pcp                                       x86_64                      5.3.7-22.0.12.el8_10.5                                 ol8_appstream                          1.4 M
 pcp-conf                                  x86_64                      5.3.7-22.0.12.el8_10.5                                 ol8_appstream                           64 k
 pcp-doc                                   noarch                      5.3.7-22.0.12.el8_10.5                                 ol8_appstream                          3.0 M
 pcp-libs                                  x86_64                      5.3.7-22.0.12.el8_10.5                                 ol8_appstream                          640 k
 pcp-pmda-dm                               x86_64                      5.3.7-22.0.12.el8_10.5                                 ol8_appstream                           78 k
 pcp-pmda-nfsclient                        x86_64                      5.3.7-22.0.12.el8_10.5                                 ol8_appstream                           59 k
 pcp-pmda-openmetrics                      x86_64                      5.3.7-22.0.12.el8_10.5                                 ol8_appstream                           69 k
 pcp-selinux                               x86_64                      5.3.7-22.0.12.el8_10.5                                 ol8_appstream                           66 k
 pcp-system-tools                          x86_64                      5.3.7-22.0.12.el8_10.5                                 ol8_appstream                          325 k
 pcp-zeroconf                              x86_64                      5.3.7-22.0.12.el8_10.5                                 ol8_appstream                           57 k
 perf                                      x86_64                      4.18.0-553.156.1.el8_10                                ol8_baseos_latest                       13 M
 platform-python                           x86_64                      3.6.8-78.0.1.el8_10                                    ol8_baseos_latest                       89 k
 python3-bind                              noarch                      32:9.11.36-16.el8_10.14                                ol8_appstream                          153 k
 python3-firewall                          noarch                      0.9.11-12.0.1.el8_10                                   ol8_baseos_latest                      436 k
 python3-idna                              noarch                      2.5-8.el8_10                                           ol8_baseos_latest                      102 k
 python3-libs                              x86_64                      3.6.8-78.0.1.el8_10                                    ol8_baseos_latest                      7.9 M
 python3-nftables                          x86_64                      1:1.0.4-8.el8_10                                       ol8_baseos_latest                       31 k
 python3-pcp                               x86_64                      5.3.7-22.0.12.el8_10.5                                 ol8_appstream                          181 k
 python3-perf                              x86_64                      4.18.0-553.156.1.el8_10                                ol8_baseos_latest                       11 M
 python3-unbound                           x86_64                      1.16.2-5.14.el8_10                                     ol8_appstream                          130 k
 sg3_utils                                 x86_64                      1.44-6.el8_10.1                                        ol8_baseos_latest                      916 k
 sg3_utils-libs                            x86_64                      1.44-6.el8_10.1                                        ol8_baseos_latest                       98 k
 systemd                                   x86_64                      239-82.0.13.el8_10.17                                  ol8_baseos_latest                      3.7 M
 systemd-libs                              x86_64                      239-82.0.13.el8_10.17                                  ol8_baseos_latest                      1.2 M
 systemd-pam                               x86_64                      239-82.0.13.el8_10.17                                  ol8_baseos_latest                      523 k
 systemd-udev                              x86_64                      239-82.0.13.el8_10.17                                  ol8_baseos_latest                      1.6 M
 unbound-libs                              x86_64                      1.16.2-5.14.el8_10                                     ol8_appstream                          578 k
Installing dependencies:
 systemtap-sdt-devel                       x86_64                      4.9-3.0.1.el8                                          ol8_appstream                           88 k

Transaction Summary
===========================================================================================================================================================================
Install   9 Packages
Upgrade  54 Packages

Total download size: 391 M
Downloading Packages:
(1/63): kernel-4.18.0-553.156.1.el8_10.x86_64.rpm                                                                                           30 MB/s |  11 MB     00:00
(2/63): kernel-devel-4.18.0-553.156.1.el8_10.x86_64.rpm                                                                                     28 MB/s |  24 MB     00:00
(3/63): systemtap-sdt-devel-4.9-3.0.1.el8.x86_64.rpm                                                                                       8.8 MB/s |  88 kB     00:00
(4/63): kernel-uek-5.15.0-323.211.3.4.el8uek.x86_64.rpm                                                                                     30 MB/s | 3.6 MB     00:00
(5/63): kernel-core-4.18.0-553.156.1.el8_10.x86_64.rpm                                                                                      29 MB/s |  44 MB     00:01
(6/63): kernel-modules-4.18.0-553.156.1.el8_10.x86_64.rpm                                                                                   26 MB/s |  36 MB     00:01
(7/63): kernel-uek-devel-5.15.0-323.211.3.4.el8uek.x86_64.rpm                                                                               26 MB/s |  22 MB     00:00
(8/63): ksplice-2.1.6-1.el8.x86_64.rpm                                                                                                      24 MB/s | 523 kB     00:00
(9/63): attr-2.6.0-1.el8_10.x86_64.rpm                                                                                                      11 MB/s |  72 kB     00:00
(10/63): bind-export-libs-9.11.36-16.el8_10.14.x86_64.rpm                                                                                   31 MB/s | 1.1 MB     00:00
(11/63): curl-7.61.1-34.el8_10.13.x86_64.rpm                                                                                                22 MB/s | 354 kB     00:00
(12/63): dracut-049-246.git20260728.0.1.el8_10.x86_64.rpm                                                                                   18 MB/s | 383 kB     00:00
(13/63): dracut-config-rescue-049-246.git20260728.0.1.el8_10.x86_64.rpm                                                                     12 MB/s |  66 kB     00:00
(14/63): dracut-network-049-246.git20260728.0.1.el8_10.x86_64.rpm                                                                           14 MB/s | 115 kB     00:00
(15/63): dracut-squash-049-246.git20260728.0.1.el8_10.x86_64.rpm                                                                            11 MB/s |  66 kB     00:00
(16/63): firewalld-0.9.11-12.0.1.el8_10.noarch.rpm                                                                                          27 MB/s | 510 kB     00:00
(17/63): firewalld-filesystem-0.9.11-12.0.1.el8_10.noarch.rpm                                                                               12 MB/s |  78 kB     00:00
(18/63): isns-utils-libs-0.99-1.el8_10.1.x86_64.rpm                                                                                         16 MB/s | 103 kB     00:00
(19/63): kernel-headers-4.18.0-553.156.1.el8_10.x86_64.rpm                                                                                  34 MB/s |  12 MB     00:00
(20/63): kernel-tools-4.18.0-553.156.1.el8_10.x86_64.rpm                                                                                    35 MB/s |  11 MB     00:00
(21/63): kernel-uek-core-5.15.0-323.211.3.4.el8uek.x86_64.rpm                                                                               23 MB/s |  64 MB     00:02
(22/63): libattr-2.6.0-1.el8_10.x86_64.rpm                                                                                                 5.0 MB/s |  26 kB     00:00
(23/63): libcurl-7.61.1-34.el8_10.13.x86_64.rpm                                                                                             23 MB/s | 307 kB     00:00
(24/63): libnghttp2-1.33.0-6.el8_10.3.x86_64.rpm                                                                                            12 MB/s |  77 kB     00:00
(25/63): libxmlb-0.3.28-2.el8_10.x86_64.rpm                                                                                                 13 MB/s | 109 kB     00:00
(26/63): kernel-tools-libs-4.18.0-553.156.1.el8_10.x86_64.rpm                                                                               13 MB/s |  11 MB     00:00
(27/63): nftables-1.0.4-8.el8_10.x86_64.rpm                                                                                                 21 MB/s | 381 kB     00:00
(28/63): pam-1.3.1-40.0.1.el8_10.x86_64.rpm                                                                                                 27 MB/s | 749 kB     00:00
(29/63): perf-4.18.0-553.156.1.el8_10.x86_64.rpm                                                                                            33 MB/s |  13 MB     00:00
(30/63): platform-python-3.6.8-78.0.1.el8_10.x86_64.rpm                                                                                     12 MB/s |  89 kB     00:00
(31/63): python3-firewall-0.9.11-12.0.1.el8_10.noarch.rpm                                                                                   25 MB/s | 436 kB     00:00
(32/63): kernel-uek-modules-5.15.0-323.211.3.4.el8uek.x86_64.rpm                                                                            18 MB/s |  74 MB     00:04
(33/63): python3-idna-2.5-8.el8_10.noarch.rpm                                                                                               75 kB/s | 102 kB     00:01
(34/63): python3-nftables-1.0.4-8.el8_10.x86_64.rpm                                                                                        4.5 MB/s |  31 kB     00:00
(35/63): microcode_ctl-20260512-1.0.1.el8_10.x86_64.rpm                                                                                    7.2 MB/s |  17 MB     00:02
(36/63): sg3_utils-1.44-6.el8_10.1.x86_64.rpm                                                                                               28 MB/s | 916 kB     00:00
(37/63): sg3_utils-libs-1.44-6.el8_10.1.x86_64.rpm                                                                                          15 MB/s |  98 kB     00:00
(38/63): systemd-239-82.0.13.el8_10.17.x86_64.rpm                                                                                           31 MB/s | 3.7 MB     00:00
(39/63): systemd-libs-239-82.0.13.el8_10.17.x86_64.rpm                                                                                      27 MB/s | 1.2 MB     00:00
(40/63): python3-libs-3.6.8-78.0.1.el8_10.x86_64.rpm                                                                                        13 MB/s | 7.9 MB     00:00
(41/63): systemd-pam-239-82.0.13.el8_10.17.x86_64.rpm                                                                                      5.6 MB/s | 523 kB     00:00
(42/63): bind-libs-9.11.36-16.el8_10.14.x86_64.rpm                                                                                          17 MB/s | 177 kB     00:00
(43/63): systemd-udev-239-82.0.13.el8_10.17.x86_64.rpm                                                                                      26 MB/s | 1.6 MB     00:00
(44/63): bind-libs-lite-9.11.36-16.el8_10.14.x86_64.rpm                                                                                     22 MB/s | 1.2 MB     00:00
(45/63): bind-utils-9.11.36-16.el8_10.14.x86_64.rpm                                                                                         23 MB/s | 454 kB     00:00
(46/63): python3-perf-4.18.0-553.156.1.el8_10.x86_64.rpm                                                                                    12 MB/s |  11 MB     00:00
(47/63): bind-license-9.11.36-16.el8_10.14.noarch.rpm                                                                                      432 kB/s | 106 kB     00:00
(48/63): pcp-conf-5.3.7-22.0.12.el8_10.5.x86_64.rpm                                                                                        7.5 MB/s |  64 kB     00:00
(49/63): pcp-5.3.7-22.0.12.el8_10.5.x86_64.rpm                                                                                             5.7 MB/s | 1.4 MB     00:00
(50/63): pcp-pmda-dm-5.3.7-22.0.12.el8_10.5.x86_64.rpm                                                                                      13 MB/s |  78 kB     00:00
(51/63): pcp-pmda-nfsclient-5.3.7-22.0.12.el8_10.5.x86_64.rpm                                                                               13 MB/s |  59 kB     00:00
(52/63): pcp-pmda-openmetrics-5.3.7-22.0.12.el8_10.5.x86_64.rpm                                                                             12 MB/s |  69 kB     00:00
(53/63): pcp-selinux-5.3.7-22.0.12.el8_10.5.x86_64.rpm                                                                                      13 MB/s |  66 kB     00:00
(54/63): pcp-system-tools-5.3.7-22.0.12.el8_10.5.x86_64.rpm                                                                                 26 MB/s | 325 kB     00:00
(55/63): pcp-zeroconf-5.3.7-22.0.12.el8_10.5.x86_64.rpm                                                                                     12 MB/s |  57 kB     00:00
(56/63): pcp-doc-5.3.7-22.0.12.el8_10.5.noarch.rpm                                                                                          30 MB/s | 3.0 MB     00:00
(57/63): python3-bind-9.11.36-16.el8_10.14.noarch.rpm                                                                                      5.2 MB/s | 153 kB     00:00
(58/63): python3-unbound-1.16.2-5.14.el8_10.x86_64.rpm                                                                                      20 MB/s | 130 kB     00:00
(59/63): unbound-libs-1.16.2-5.14.el8_10.x86_64.rpm                                                                                         41 MB/s | 578 kB     00:00
(60/63): pcp-libs-5.3.7-22.0.12.el8_10.5.x86_64.rpm                                                                                        4.4 MB/s | 640 kB     00:00
(61/63): bpftool-5.15.0-323.211.3.4.el8uek.x86_64.rpm                                                                                       38 MB/s | 4.4 MB     00:00
(62/63): python3-pcp-5.3.7-22.0.12.el8_10.5.x86_64.rpm                                                                                     1.2 MB/s | 181 kB     00:00
(63/63): dtrace-2.0.7-4.el8.x86_64.rpm                                                                                                      27 MB/s | 4.8 MB     00:00
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                                                       55 MB/s | 391 MB     00:07
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Running scriptlet: ksplice-2.1.6-1.el8.x86_64                                                                                                                        1/1
  Preparing        :                                                                                                                                                   1/1
  Running scriptlet: python3-libs-3.6.8-78.0.1.el8_10.x86_64                                                                                                           1/1
  Upgrading        : python3-libs-3.6.8-78.0.1.el8_10.x86_64                                                                                                         1/119
  Upgrading        : platform-python-3.6.8-78.0.1.el8_10.x86_64                                                                                                      2/119
  Running scriptlet: platform-python-3.6.8-78.0.1.el8_10.x86_64                                                                                                      2/119
  Upgrading        : bind-license-32:9.11.36-16.el8_10.14.noarch                                                                                                     3/119
  Upgrading        : bind-libs-lite-32:9.11.36-16.el8_10.14.x86_64                                                                                                   4/119
  Upgrading        : systemd-libs-239-82.0.13.el8_10.17.x86_64                                                                                                       5/119
  Running scriptlet: systemd-libs-239-82.0.13.el8_10.17.x86_64                                                                                                       5/119
  Upgrading        : pam-1.3.1-40.0.1.el8_10.x86_64                                                                                                                  6/119
  Running scriptlet: pam-1.3.1-40.0.1.el8_10.x86_64                                                                                                                  6/119
  Running scriptlet: systemd-239-82.0.13.el8_10.17.x86_64                                                                                                            7/119
  Upgrading        : systemd-239-82.0.13.el8_10.17.x86_64                                                                                                            7/119
  Running scriptlet: systemd-239-82.0.13.el8_10.17.x86_64                                                                                                            7/119
  Upgrading        : systemd-pam-239-82.0.13.el8_10.17.x86_64                                                                                                        8/119
  Upgrading        : systemd-udev-239-82.0.13.el8_10.17.x86_64                                                                                                       9/119
  Running scriptlet: systemd-udev-239-82.0.13.el8_10.17.x86_64                                                                                                       9/119
  Upgrading        : dracut-049-246.git20260728.0.1.el8_10.x86_64                                                                                                   10/119
  Installing       : kernel-core-4.18.0-553.156.1.el8_10.x86_64                                                                                                     11/119
  Running scriptlet: kernel-core-4.18.0-553.156.1.el8_10.x86_64                                                                                                     11/119
  Running scriptlet: kernel-uek-core-5.15.0-323.211.3.4.el8uek.x86_64                                                                                               12/119
  Installing       : kernel-uek-core-5.15.0-323.211.3.4.el8uek.x86_64                                                                                               12/119
  Running scriptlet: kernel-uek-core-5.15.0-323.211.3.4.el8uek.x86_64                                                                                               12/119
  Installing       : kernel-uek-modules-5.15.0-323.211.3.4.el8uek.x86_64                                                                                            13/119
  Running scriptlet: kernel-uek-modules-5.15.0-323.211.3.4.el8uek.x86_64                                                                                            13/119
  Installing       : kernel-modules-4.18.0-553.156.1.el8_10.x86_64                                                                                                  14/119
  Running scriptlet: kernel-modules-4.18.0-553.156.1.el8_10.x86_64                                                                                                  14/119
  Running scriptlet: unbound-libs-1.16.2-5.14.el8_10.x86_64                                                                                                         15/119
  Upgrading        : unbound-libs-1.16.2-5.14.el8_10.x86_64                                                                                                         15/119
  Running scriptlet: unbound-libs-1.16.2-5.14.el8_10.x86_64                                                                                                         15/119
  Upgrading        : bind-libs-32:9.11.36-16.el8_10.14.x86_64                                                                                                       16/119
  Upgrading        : python3-bind-32:9.11.36-16.el8_10.14.noarch                                                                                                    17/119
  Running scriptlet: pcp-selinux-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                      18/119
  Upgrading        : pcp-selinux-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                      18/119
  Running scriptlet: pcp-selinux-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                      18/119
  Upgrading        : pcp-doc-5.3.7-22.0.12.el8_10.5.noarch                                                                                                          19/119
  Upgrading        : pcp-conf-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                         20/119
  Upgrading        : pcp-libs-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                         21/119
  Running scriptlet: pcp-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                              22/119
  Upgrading        : pcp-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                              22/119
  Running scriptlet: pcp-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                              22/119
  Upgrading        : python3-pcp-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                      23/119
  Upgrading        : pcp-pmda-nfsclient-5.3.7-22.0.12.el8_10.5.x86_64                                                                                               24/119
  Upgrading        : pcp-pmda-openmetrics-5.3.7-22.0.12.el8_10.5.x86_64                                                                                             25/119
  Upgrading        : pcp-system-tools-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                 26/119
  Upgrading        : pcp-pmda-dm-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                      27/119
  Upgrading        : sg3_utils-libs-1.44-6.el8_10.1.x86_64                                                                                                          28/119
  Running scriptlet: sg3_utils-libs-1.44-6.el8_10.1.x86_64                                                                                                          28/119
  Upgrading        : nftables-1:1.0.4-8.el8_10.x86_64                                                                                                               29/119
  Running scriptlet: nftables-1:1.0.4-8.el8_10.x86_64                                                                                                               29/119
  Upgrading        : python3-nftables-1:1.0.4-8.el8_10.x86_64                                                                                                       30/119
  Upgrading        : python3-firewall-0.9.11-12.0.1.el8_10.noarch                                                                                                   31/119
  Upgrading        : libnghttp2-1.33.0-6.el8_10.3.x86_64                                                                                                            32/119
  Upgrading        : libcurl-7.61.1-34.el8_10.13.x86_64                                                                                                             33/119
  Upgrading        : libattr-2.6.0-1.el8_10.x86_64                                                                                                                  34/119
  Upgrading        : kernel-tools-libs-4.18.0-553.156.1.el8_10.x86_64                                                                                               35/119
  Running scriptlet: kernel-tools-libs-4.18.0-553.156.1.el8_10.x86_64                                                                                               35/119
  Upgrading        : firewalld-filesystem-0.9.11-12.0.1.el8_10.noarch                                                                                               36/119
  Upgrading        : firewalld-0.9.11-12.0.1.el8_10.noarch                                                                                                          37/119
  Running scriptlet: firewalld-0.9.11-12.0.1.el8_10.noarch                                                                                                          37/119
  Upgrading        : kernel-tools-4.18.0-553.156.1.el8_10.x86_64                                                                                                    38/119
  Running scriptlet: kernel-tools-4.18.0-553.156.1.el8_10.x86_64                                                                                                    38/119
  Upgrading        : attr-2.6.0-1.el8_10.x86_64                                                                                                                     39/119
  Upgrading        : curl-7.61.1-34.el8_10.13.x86_64                                                                                                                40/119
  Upgrading        : sg3_utils-1.44-6.el8_10.1.x86_64                                                                                                               41/119
  Upgrading        : pcp-zeroconf-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                     42/119
  Running scriptlet: pcp-zeroconf-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                     42/119
  Upgrading        : bind-utils-32:9.11.36-16.el8_10.14.x86_64                                                                                                      43/119
  Upgrading        : python3-unbound-1.16.2-5.14.el8_10.x86_64                                                                                                      44/119
  Installing       : kernel-4.18.0-553.156.1.el8_10.x86_64                                                                                                          45/119
  Installing       : kernel-uek-5.15.0-323.211.3.4.el8uek.x86_64                                                                                                    46/119
  Upgrading        : dracut-config-rescue-049-246.git20260728.0.1.el8_10.x86_64                                                                                     47/119
  Upgrading        : dracut-network-049-246.git20260728.0.1.el8_10.x86_64                                                                                           48/119
  Upgrading        : dracut-squash-049-246.git20260728.0.1.el8_10.x86_64                                                                                            49/119
  Upgrading        : microcode_ctl-4:20260512-1.0.1.el8_10.x86_64                                                                                                   50/119
  Running scriptlet: microcode_ctl-4:20260512-1.0.1.el8_10.x86_64                                                                                                   50/119
  Upgrading        : dtrace-2.0.7-4.el8.x86_64                                                                                                                      51/119
  Running scriptlet: dtrace-2.0.7-4.el8.x86_64                                                                                                                      51/119
  Installing       : systemtap-sdt-devel-4.9-3.0.1.el8.x86_64                                                                                                       52/119
  Running scriptlet: ksplice-2.1.6-1.el8.x86_64                                                                                                                     53/119
  Upgrading        : ksplice-2.1.6-1.el8.x86_64                                                                                                                     53/119
  Running scriptlet: ksplice-2.1.6-1.el8.x86_64                                                                                                                     53/119
  Upgrading        : python3-idna-2.5-8.el8_10.noarch                                                                                                               54/119
  Upgrading        : python3-perf-4.18.0-553.156.1.el8_10.x86_64                                                                                                    55/119
  Upgrading        : perf-4.18.0-553.156.1.el8_10.x86_64                                                                                                            56/119
  Upgrading        : bpftool-5.15.0-323.211.3.4.el8uek.x86_64                                                                                                       57/119
  Upgrading        : libxmlb-0.3.28-2.el8_10.x86_64                                                                                                                 58/119
  Upgrading        : kernel-headers-4.18.0-553.156.1.el8_10.x86_64                                                                                                  59/119
  Upgrading        : isns-utils-libs-0.99-1.el8_10.1.x86_64                                                                                                         60/119
  Running scriptlet: isns-utils-libs-0.99-1.el8_10.1.x86_64                                                                                                         60/119
  Upgrading        : bind-export-libs-32:9.11.36-16.el8_10.14.x86_64                                                                                                61/119
  Running scriptlet: bind-export-libs-32:9.11.36-16.el8_10.14.x86_64                                                                                                61/119
  Installing       : kernel-uek-devel-5.15.0-323.211.3.4.el8uek.x86_64                                                                                              62/119
  Running scriptlet: kernel-uek-devel-5.15.0-323.211.3.4.el8uek.x86_64                                                                                              62/119
  Installing       : kernel-devel-4.18.0-553.156.1.el8_10.x86_64                                                                                                    63/119
  Running scriptlet: kernel-devel-4.18.0-553.156.1.el8_10.x86_64                                                                                                    63/119
  Running scriptlet: pcp-zeroconf-5.3.7-22.0.12.el8_10.x86_64                                                                                                       64/119
  Cleanup          : pcp-zeroconf-5.3.7-22.0.12.el8_10.x86_64                                                                                                       64/119
  Running scriptlet: firewalld-0.9.11-11.0.1.el8_10.noarch                                                                                                          65/119
  Cleanup          : firewalld-0.9.11-11.0.1.el8_10.noarch                                                                                                          65/119
  Running scriptlet: firewalld-0.9.11-11.0.1.el8_10.noarch                                                                                                          65/119
  Running scriptlet: pcp-pmda-nfsclient-5.3.7-22.0.12.el8_10.x86_64                                                                                                 66/119
  Cleanup          : pcp-pmda-nfsclient-5.3.7-22.0.12.el8_10.x86_64                                                                                                 66/119
  Running scriptlet: pcp-pmda-openmetrics-5.3.7-22.0.12.el8_10.x86_64                                                                                               67/119
  Cleanup          : pcp-pmda-openmetrics-5.3.7-22.0.12.el8_10.x86_64                                                                                               67/119
  Running scriptlet: microcode_ctl-4:20260227-1.0.1.el8_10.x86_64                                                                                                   68/119
  Cleanup          : microcode_ctl-4:20260227-1.0.1.el8_10.x86_64                                                                                                   68/119
  Running scriptlet: microcode_ctl-4:20260227-1.0.1.el8_10.x86_64                                                                                                   68/119
  Cleanup          : python3-firewall-0.9.11-11.0.1.el8_10.noarch                                                                                                   69/119
  Cleanup          : python3-nftables-1:1.0.4-7.el8_10.x86_64                                                                                                       70/119
  Running scriptlet: ksplice-2.1.2-1.el8.x86_64                                                                                                                     71/119
  Cleanup          : ksplice-2.1.2-1.el8.x86_64                                                                                                                     71/119
  Running scriptlet: ksplice-2.1.2-1.el8.x86_64                                                                                                                     71/119
  Cleanup          : pcp-system-tools-5.3.7-22.0.12.el8_10.x86_64                                                                                                   72/119
  Cleanup          : python3-pcp-5.3.7-22.0.12.el8_10.x86_64                                                                                                        73/119
  Cleanup          : bind-utils-32:9.11.36-16.el8_10.8.x86_64                                                                                                       74/119
  Running scriptlet: pcp-pmda-dm-5.3.7-22.0.12.el8_10.x86_64                                                                                                        75/119
  Cleanup          : pcp-pmda-dm-5.3.7-22.0.12.el8_10.x86_64                                                                                                        75/119
  Running scriptlet: pcp-5.3.7-22.0.12.el8_10.x86_64                                                                                                                76/119
  Cleanup          : pcp-5.3.7-22.0.12.el8_10.x86_64                                                                                                                76/119
  Cleanup          : bind-libs-32:9.11.36-16.el8_10.8.x86_64                                                                                                        77/119
  Running scriptlet: dtrace-2.0.1-1.el8.x86_64                                                                                                                      78/119
  Cleanup          : dtrace-2.0.1-1.el8.x86_64                                                                                                                      78/119
  Running scriptlet: dtrace-2.0.1-1.el8.x86_64                                                                                                                      78/119
  Cleanup          : python3-unbound-1.16.2-5.12.el8_10.x86_64                                                                                                      79/119
  Running scriptlet: unbound-libs-1.16.2-5.12.el8_10.x86_64                                                                                                         80/119
  Cleanup          : unbound-libs-1.16.2-5.12.el8_10.x86_64                                                                                                         80/119
  Running scriptlet: unbound-libs-1.16.2-5.12.el8_10.x86_64                                                                                                         80/119
  Cleanup          : attr-2.4.48-3.el8.x86_64                                                                                                                       81/119
  Cleanup          : python3-bind-32:9.11.36-16.el8_10.8.noarch                                                                                                     82/119
  Running scriptlet: ksplice-tools-2.1.2-1.el8.x86_64                                                                                                               83/119
  Obsoleting       : ksplice-tools-2.1.2-1.el8.x86_64                                                                                                               83/119
  Cleanup          : pcp-libs-5.3.7-22.0.12.el8_10.x86_64                                                                                                           84/119
  Running scriptlet: kernel-tools-4.18.0-553.153.1.el8_10.x86_64                                                                                                    85/119
  Cleanup          : kernel-tools-4.18.0-553.153.1.el8_10.x86_64                                                                                                    85/119
  Running scriptlet: kernel-tools-4.18.0-553.153.1.el8_10.x86_64                                                                                                    85/119
  Cleanup          : sg3_utils-1.44-6.el8.x86_64                                                                                                                    86/119
  Cleanup          : python3-perf-4.18.0-553.153.1.el8_10.x86_64                                                                                                    87/119
  Cleanup          : curl-7.61.1-34.el8_10.11.x86_64                                                                                                                88/119
  Cleanup          : python3-idna-2.5-7.el8_10.noarch                                                                                                               89/119
  Cleanup          : dracut-squash-049-244.git20260529.0.1.el8_10.x86_64                                                                                            90/119
  Cleanup          : dracut-network-049-244.git20260529.0.1.el8_10.x86_64                                                                                           91/119
  Cleanup          : dracut-config-rescue-049-244.git20260529.0.1.el8_10.x86_64                                                                                     92/119
  Cleanup          : pcp-conf-5.3.7-22.0.12.el8_10.x86_64                                                                                                           93/119
  Cleanup          : pcp-selinux-5.3.7-22.0.12.el8_10.x86_64                                                                                                        94/119
  Running scriptlet: pcp-selinux-5.3.7-22.0.12.el8_10.x86_64                                                                                                        94/119
  Cleanup          : firewalld-filesystem-0.9.11-11.0.1.el8_10.noarch                                                                                               95/119
  Cleanup          : pcp-doc-5.3.7-22.0.12.el8_10.noarch                                                                                                            96/119
  Cleanup          : kernel-headers-4.18.0-553.153.1.el8_10.x86_64                                                                                                  97/119
  Cleanup          : dracut-049-244.git20260529.0.1.el8_10.x86_64                                                                                                   98/119
  Cleanup          : systemd-udev-239-82.0.12.el8_10.17.x86_64                                                                                                      99/119
  Running scriptlet: systemd-udev-239-82.0.12.el8_10.17.x86_64                                                                                                      99/119
  Running scriptlet: systemd-239-82.0.12.el8_10.17.x86_64                                                                                                          100/119
  Cleanup          : systemd-239-82.0.12.el8_10.17.x86_64                                                                                                          100/119
  Cleanup          : systemd-pam-239-82.0.12.el8_10.17.x86_64                                                                                                      101/119
  Cleanup          : libcurl-7.61.1-34.el8_10.11.x86_64                                                                                                            102/119
  Obsoleting       : ksplice-core0-2.1.2-1.el8.x86_64                                                                                                              103/119
  Running scriptlet: ksplice-core0-2.1.2-1.el8.x86_64                                                                                                              103/119
  Cleanup          : platform-python-3.6.8-77.0.1.el8_10.x86_64                                                                                                    104/119
  Running scriptlet: platform-python-3.6.8-77.0.1.el8_10.x86_64                                                                                                    104/119
  Cleanup          : bind-libs-lite-32:9.11.36-16.el8_10.8.x86_64                                                                                                  105/119
  Cleanup          : perf-4.18.0-553.153.1.el8_10.x86_64                                                                                                           106/119
  Cleanup          : bind-license-32:9.11.36-16.el8_10.8.noarch                                                                                                    107/119
  Cleanup          : python3-libs-3.6.8-77.0.1.el8_10.x86_64                                                                                                       108/119
  Cleanup          : libnghttp2-1.33.0-6.el8_10.2.x86_64                                                                                                           109/119
  Cleanup          : pam-1.3.1-39.0.1.el8_10.x86_64                                                                                                                110/119
  Running scriptlet: pam-1.3.1-39.0.1.el8_10.x86_64                                                                                                                110/119
  Cleanup          : systemd-libs-239-82.0.12.el8_10.17.x86_64                                                                                                     111/119
  Cleanup          : sg3_utils-libs-1.44-6.el8.x86_64                                                                                                              112/119
  Running scriptlet: sg3_utils-libs-1.44-6.el8.x86_64                                                                                                              112/119
  Cleanup          : kernel-tools-libs-4.18.0-553.153.1.el8_10.x86_64                                                                                              113/119
  Running scriptlet: kernel-tools-libs-4.18.0-553.153.1.el8_10.x86_64                                                                                              113/119
  Cleanup          : libattr-2.4.48-3.el8.x86_64                                                                                                                   114/119
  Running scriptlet: nftables-1:1.0.4-7.el8_10.x86_64                                                                                                              115/119
  Cleanup          : nftables-1:1.0.4-7.el8_10.x86_64                                                                                                              115/119
  Running scriptlet: nftables-1:1.0.4-7.el8_10.x86_64                                                                                                              115/119
  Cleanup          : bpftool-5.15.0-322.203.3.4.5.el8uek.x86_64                                                                                                    116/119
  Cleanup          : libxmlb-0.3.28-1.el8_10.x86_64                                                                                                                117/119
  Cleanup          : isns-utils-libs-0.99-1.el8.x86_64                                                                                                             118/119
  Running scriptlet: isns-utils-libs-0.99-1.el8.x86_64                                                                                                             118/119
  Cleanup          : bind-export-libs-32:9.11.36-16.el8_10.8.x86_64                                                                                                119/119
  Running scriptlet: bind-export-libs-32:9.11.36-16.el8_10.8.x86_64                                                                                                119/119
  Running scriptlet: systemd-239-82.0.13.el8_10.17.x86_64                                                                                                          119/119
  Running scriptlet: kernel-core-4.18.0-553.156.1.el8_10.x86_64                                                                                                    119/119
2026-08-22 06:44:48,506 - INFO - Processing directory: /var/cache/uptrack/Linux/x86_64
2026-08-22 06:44:48,506 - INFO - Kept (running kernel): /var/cache/uptrack/Linux/x86_64/5.15.0-322.203.3.5.el8uek.x86_64
2026-08-22 06:44:48,506 - INFO - Directory cleaned up successfully: /var/cache/uptrack

  Running scriptlet: kernel-uek-core-5.15.0-323.211.3.4.el8uek.x86_64                                                                                              119/119
2026-08-22 06:46:32,119 - INFO - Processing directory: /var/cache/uptrack/Linux/x86_64
2026-08-22 06:46:32,120 - INFO - Kept (running kernel): /var/cache/uptrack/Linux/x86_64/5.15.0-322.203.3.5.el8uek.x86_64
2026-08-22 06:46:32,120 - INFO - Directory cleaned up successfully: /var/cache/uptrack

  Running scriptlet: kernel-modules-4.18.0-553.156.1.el8_10.x86_64                                                                                                 119/119
  Running scriptlet: microcode_ctl-4:20260512-1.0.1.el8_10.x86_64                                                                                                  119/119
  Running scriptlet: dtrace-2.0.7-4.el8.x86_64                                                                                                                     119/119
  Running scriptlet: ksplice-2.1.6-1.el8.x86_64                                                                                                                    119/119
Enabling and starting the ksplice-agent.timer systemd service.
There are no existing modules on disk that need basename migration.

  Running scriptlet: bind-export-libs-32:9.11.36-16.el8_10.8.x86_64                                                                                                119/119
  Running scriptlet: systemd-239-82.0.13.el8_10.17.x86_64                                                                                                          119/119
  Running scriptlet: systemd-udev-239-82.0.13.el8_10.17.x86_64                                                                                                     119/119
  Verifying        : kernel-4.18.0-553.156.1.el8_10.x86_64                                                                                                           1/119
  Verifying        : kernel-core-4.18.0-553.156.1.el8_10.x86_64                                                                                                      2/119
  Verifying        : kernel-devel-4.18.0-553.156.1.el8_10.x86_64                                                                                                     3/119
  Verifying        : kernel-modules-4.18.0-553.156.1.el8_10.x86_64                                                                                                   4/119
  Verifying        : systemtap-sdt-devel-4.9-3.0.1.el8.x86_64                                                                                                        5/119
  Verifying        : kernel-uek-5.15.0-323.211.3.4.el8uek.x86_64                                                                                                     6/119
  Verifying        : kernel-uek-core-5.15.0-323.211.3.4.el8uek.x86_64                                                                                                7/119
  Verifying        : kernel-uek-devel-5.15.0-323.211.3.4.el8uek.x86_64                                                                                               8/119
  Verifying        : kernel-uek-modules-5.15.0-323.211.3.4.el8uek.x86_64                                                                                             9/119
  Verifying        : ksplice-2.1.6-1.el8.x86_64                                                                                                                     10/119
  Verifying        : ksplice-2.1.2-1.el8.x86_64                                                                                                                     11/119
  Verifying        : ksplice-core0-2.1.2-1.el8.x86_64                                                                                                               12/119
  Verifying        : ksplice-tools-2.1.2-1.el8.x86_64                                                                                                               13/119
  Verifying        : attr-2.6.0-1.el8_10.x86_64                                                                                                                     14/119
  Verifying        : attr-2.4.48-3.el8.x86_64                                                                                                                       15/119
  Verifying        : bind-export-libs-32:9.11.36-16.el8_10.14.x86_64                                                                                                16/119
  Verifying        : bind-export-libs-32:9.11.36-16.el8_10.8.x86_64                                                                                                 17/119
  Verifying        : curl-7.61.1-34.el8_10.13.x86_64                                                                                                                18/119
  Verifying        : curl-7.61.1-34.el8_10.11.x86_64                                                                                                                19/119
  Verifying        : dracut-049-246.git20260728.0.1.el8_10.x86_64                                                                                                   20/119
  Verifying        : dracut-049-244.git20260529.0.1.el8_10.x86_64                                                                                                   21/119
  Verifying        : dracut-config-rescue-049-246.git20260728.0.1.el8_10.x86_64                                                                                     22/119
  Verifying        : dracut-config-rescue-049-244.git20260529.0.1.el8_10.x86_64                                                                                     23/119
  Verifying        : dracut-network-049-246.git20260728.0.1.el8_10.x86_64                                                                                           24/119
  Verifying        : dracut-network-049-244.git20260529.0.1.el8_10.x86_64                                                                                           25/119
  Verifying        : dracut-squash-049-246.git20260728.0.1.el8_10.x86_64                                                                                            26/119
  Verifying        : dracut-squash-049-244.git20260529.0.1.el8_10.x86_64                                                                                            27/119
  Verifying        : firewalld-0.9.11-12.0.1.el8_10.noarch                                                                                                          28/119
  Verifying        : firewalld-0.9.11-11.0.1.el8_10.noarch                                                                                                          29/119
  Verifying        : firewalld-filesystem-0.9.11-12.0.1.el8_10.noarch                                                                                               30/119
  Verifying        : firewalld-filesystem-0.9.11-11.0.1.el8_10.noarch                                                                                               31/119
  Verifying        : isns-utils-libs-0.99-1.el8_10.1.x86_64                                                                                                         32/119
  Verifying        : isns-utils-libs-0.99-1.el8.x86_64                                                                                                              33/119
  Verifying        : kernel-headers-4.18.0-553.156.1.el8_10.x86_64                                                                                                  34/119
  Verifying        : kernel-headers-4.18.0-553.153.1.el8_10.x86_64                                                                                                  35/119
  Verifying        : kernel-tools-4.18.0-553.156.1.el8_10.x86_64                                                                                                    36/119
  Verifying        : kernel-tools-4.18.0-553.153.1.el8_10.x86_64                                                                                                    37/119
  Verifying        : kernel-tools-libs-4.18.0-553.156.1.el8_10.x86_64                                                                                               38/119
  Verifying        : kernel-tools-libs-4.18.0-553.153.1.el8_10.x86_64                                                                                               39/119
  Verifying        : libattr-2.6.0-1.el8_10.x86_64                                                                                                                  40/119
  Verifying        : libattr-2.4.48-3.el8.x86_64                                                                                                                    41/119
  Verifying        : libcurl-7.61.1-34.el8_10.13.x86_64                                                                                                             42/119
  Verifying        : libcurl-7.61.1-34.el8_10.11.x86_64                                                                                                             43/119
  Verifying        : libnghttp2-1.33.0-6.el8_10.3.x86_64                                                                                                            44/119
  Verifying        : libnghttp2-1.33.0-6.el8_10.2.x86_64                                                                                                            45/119
  Verifying        : libxmlb-0.3.28-2.el8_10.x86_64                                                                                                                 46/119
  Verifying        : libxmlb-0.3.28-1.el8_10.x86_64                                                                                                                 47/119
  Verifying        : microcode_ctl-4:20260512-1.0.1.el8_10.x86_64                                                                                                   48/119
  Verifying        : microcode_ctl-4:20260227-1.0.1.el8_10.x86_64                                                                                                   49/119
  Verifying        : nftables-1:1.0.4-8.el8_10.x86_64                                                                                                               50/119
  Verifying        : nftables-1:1.0.4-7.el8_10.x86_64                                                                                                               51/119
  Verifying        : pam-1.3.1-40.0.1.el8_10.x86_64                                                                                                                 52/119
  Verifying        : pam-1.3.1-39.0.1.el8_10.x86_64                                                                                                                 53/119
  Verifying        : perf-4.18.0-553.156.1.el8_10.x86_64                                                                                                            54/119
  Verifying        : perf-4.18.0-553.153.1.el8_10.x86_64                                                                                                            55/119
  Verifying        : platform-python-3.6.8-78.0.1.el8_10.x86_64                                                                                                     56/119
  Verifying        : platform-python-3.6.8-77.0.1.el8_10.x86_64                                                                                                     57/119
  Verifying        : python3-firewall-0.9.11-12.0.1.el8_10.noarch                                                                                                   58/119
  Verifying        : python3-firewall-0.9.11-11.0.1.el8_10.noarch                                                                                                   59/119
  Verifying        : python3-idna-2.5-8.el8_10.noarch                                                                                                               60/119
  Verifying        : python3-idna-2.5-7.el8_10.noarch                                                                                                               61/119
  Verifying        : python3-libs-3.6.8-78.0.1.el8_10.x86_64                                                                                                        62/119
  Verifying        : python3-libs-3.6.8-77.0.1.el8_10.x86_64                                                                                                        63/119
  Verifying        : python3-nftables-1:1.0.4-8.el8_10.x86_64                                                                                                       64/119
  Verifying        : python3-nftables-1:1.0.4-7.el8_10.x86_64                                                                                                       65/119
  Verifying        : python3-perf-4.18.0-553.156.1.el8_10.x86_64                                                                                                    66/119
  Verifying        : python3-perf-4.18.0-553.153.1.el8_10.x86_64                                                                                                    67/119
  Verifying        : sg3_utils-1.44-6.el8_10.1.x86_64                                                                                                               68/119
  Verifying        : sg3_utils-1.44-6.el8.x86_64                                                                                                                    69/119
  Verifying        : sg3_utils-libs-1.44-6.el8_10.1.x86_64                                                                                                          70/119
  Verifying        : sg3_utils-libs-1.44-6.el8.x86_64                                                                                                               71/119
  Verifying        : systemd-239-82.0.13.el8_10.17.x86_64                                                                                                           72/119
  Verifying        : systemd-239-82.0.12.el8_10.17.x86_64                                                                                                           73/119
  Verifying        : systemd-libs-239-82.0.13.el8_10.17.x86_64                                                                                                      74/119
  Verifying        : systemd-libs-239-82.0.12.el8_10.17.x86_64                                                                                                      75/119
  Verifying        : systemd-pam-239-82.0.13.el8_10.17.x86_64                                                                                                       76/119
  Verifying        : systemd-pam-239-82.0.12.el8_10.17.x86_64                                                                                                       77/119
  Verifying        : systemd-udev-239-82.0.13.el8_10.17.x86_64                                                                                                      78/119
  Verifying        : systemd-udev-239-82.0.12.el8_10.17.x86_64                                                                                                      79/119
  Verifying        : bind-libs-32:9.11.36-16.el8_10.14.x86_64                                                                                                       80/119
  Verifying        : bind-libs-32:9.11.36-16.el8_10.8.x86_64                                                                                                        81/119
  Verifying        : bind-libs-lite-32:9.11.36-16.el8_10.14.x86_64                                                                                                  82/119
  Verifying        : bind-libs-lite-32:9.11.36-16.el8_10.8.x86_64                                                                                                   83/119
  Verifying        : bind-license-32:9.11.36-16.el8_10.14.noarch                                                                                                    84/119
  Verifying        : bind-license-32:9.11.36-16.el8_10.8.noarch                                                                                                     85/119
  Verifying        : bind-utils-32:9.11.36-16.el8_10.14.x86_64                                                                                                      86/119
  Verifying        : bind-utils-32:9.11.36-16.el8_10.8.x86_64                                                                                                       87/119
  Verifying        : pcp-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                              88/119
  Verifying        : pcp-5.3.7-22.0.12.el8_10.x86_64                                                                                                                89/119
  Verifying        : pcp-conf-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                         90/119
  Verifying        : pcp-conf-5.3.7-22.0.12.el8_10.x86_64                                                                                                           91/119
  Verifying        : pcp-doc-5.3.7-22.0.12.el8_10.5.noarch                                                                                                          92/119
  Verifying        : pcp-doc-5.3.7-22.0.12.el8_10.noarch                                                                                                            93/119
  Verifying        : pcp-libs-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                         94/119
  Verifying        : pcp-libs-5.3.7-22.0.12.el8_10.x86_64                                                                                                           95/119
  Verifying        : pcp-pmda-dm-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                      96/119
  Verifying        : pcp-pmda-dm-5.3.7-22.0.12.el8_10.x86_64                                                                                                        97/119
  Verifying        : pcp-pmda-nfsclient-5.3.7-22.0.12.el8_10.5.x86_64                                                                                               98/119
  Verifying        : pcp-pmda-nfsclient-5.3.7-22.0.12.el8_10.x86_64                                                                                                 99/119
  Verifying        : pcp-pmda-openmetrics-5.3.7-22.0.12.el8_10.5.x86_64                                                                                            100/119
  Verifying        : pcp-pmda-openmetrics-5.3.7-22.0.12.el8_10.x86_64                                                                                              101/119
  Verifying        : pcp-selinux-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                     102/119
  Verifying        : pcp-selinux-5.3.7-22.0.12.el8_10.x86_64                                                                                                       103/119
  Verifying        : pcp-system-tools-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                104/119
  Verifying        : pcp-system-tools-5.3.7-22.0.12.el8_10.x86_64                                                                                                  105/119
  Verifying        : pcp-zeroconf-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                    106/119
  Verifying        : pcp-zeroconf-5.3.7-22.0.12.el8_10.x86_64                                                                                                      107/119
  Verifying        : python3-bind-32:9.11.36-16.el8_10.14.noarch                                                                                                   108/119
  Verifying        : python3-bind-32:9.11.36-16.el8_10.8.noarch                                                                                                    109/119
  Verifying        : python3-pcp-5.3.7-22.0.12.el8_10.5.x86_64                                                                                                     110/119
  Verifying        : python3-pcp-5.3.7-22.0.12.el8_10.x86_64                                                                                                       111/119
  Verifying        : python3-unbound-1.16.2-5.14.el8_10.x86_64                                                                                                     112/119
  Verifying        : python3-unbound-1.16.2-5.12.el8_10.x86_64                                                                                                     113/119
  Verifying        : unbound-libs-1.16.2-5.14.el8_10.x86_64                                                                                                        114/119
  Verifying        : unbound-libs-1.16.2-5.12.el8_10.x86_64                                                                                                        115/119
  Verifying        : bpftool-5.15.0-323.211.3.4.el8uek.x86_64                                                                                                      116/119
  Verifying        : bpftool-5.15.0-322.203.3.4.5.el8uek.x86_64                                                                                                    117/119
  Verifying        : dtrace-2.0.7-4.el8.x86_64                                                                                                                     118/119
  Verifying        : dtrace-2.0.1-1.el8.x86_64                                                                                                                     119/119

Upgraded:
  attr-2.6.0-1.el8_10.x86_64                                   bind-export-libs-32:9.11.36-16.el8_10.14.x86_64        bind-libs-32:9.11.36-16.el8_10.14.x86_64
  bind-libs-lite-32:9.11.36-16.el8_10.14.x86_64                bind-license-32:9.11.36-16.el8_10.14.noarch            bind-utils-32:9.11.36-16.el8_10.14.x86_64
  bpftool-5.15.0-323.211.3.4.el8uek.x86_64                     curl-7.61.1-34.el8_10.13.x86_64                        dracut-049-246.git20260728.0.1.el8_10.x86_64
  dracut-config-rescue-049-246.git20260728.0.1.el8_10.x86_64   dracut-network-049-246.git20260728.0.1.el8_10.x86_64   dracut-squash-049-246.git20260728.0.1.el8_10.x86_64
  dtrace-2.0.7-4.el8.x86_64                                    firewalld-0.9.11-12.0.1.el8_10.noarch                  firewalld-filesystem-0.9.11-12.0.1.el8_10.noarch
  isns-utils-libs-0.99-1.el8_10.1.x86_64                       kernel-headers-4.18.0-553.156.1.el8_10.x86_64          kernel-tools-4.18.0-553.156.1.el8_10.x86_64
  kernel-tools-libs-4.18.0-553.156.1.el8_10.x86_64             ksplice-2.1.6-1.el8.x86_64                             libattr-2.6.0-1.el8_10.x86_64
  libcurl-7.61.1-34.el8_10.13.x86_64                           libnghttp2-1.33.0-6.el8_10.3.x86_64                    libxmlb-0.3.28-2.el8_10.x86_64
  microcode_ctl-4:20260512-1.0.1.el8_10.x86_64                 nftables-1:1.0.4-8.el8_10.x86_64                       pam-1.3.1-40.0.1.el8_10.x86_64
  pcp-5.3.7-22.0.12.el8_10.5.x86_64                            pcp-conf-5.3.7-22.0.12.el8_10.5.x86_64                 pcp-doc-5.3.7-22.0.12.el8_10.5.noarch
  pcp-libs-5.3.7-22.0.12.el8_10.5.x86_64                       pcp-pmda-dm-5.3.7-22.0.12.el8_10.5.x86_64              pcp-pmda-nfsclient-5.3.7-22.0.12.el8_10.5.x86_64
  pcp-pmda-openmetrics-5.3.7-22.0.12.el8_10.5.x86_64           pcp-selinux-5.3.7-22.0.12.el8_10.5.x86_64              pcp-system-tools-5.3.7-22.0.12.el8_10.5.x86_64
  pcp-zeroconf-5.3.7-22.0.12.el8_10.5.x86_64                   perf-4.18.0-553.156.1.el8_10.x86_64                    platform-python-3.6.8-78.0.1.el8_10.x86_64
  python3-bind-32:9.11.36-16.el8_10.14.noarch                  python3-firewall-0.9.11-12.0.1.el8_10.noarch           python3-idna-2.5-8.el8_10.noarch
  python3-libs-3.6.8-78.0.1.el8_10.x86_64                      python3-nftables-1:1.0.4-8.el8_10.x86_64               python3-pcp-5.3.7-22.0.12.el8_10.5.x86_64
  python3-perf-4.18.0-553.156.1.el8_10.x86_64                  python3-unbound-1.16.2-5.14.el8_10.x86_64              sg3_utils-1.44-6.el8_10.1.x86_64
  sg3_utils-libs-1.44-6.el8_10.1.x86_64                        systemd-239-82.0.13.el8_10.17.x86_64                   systemd-libs-239-82.0.13.el8_10.17.x86_64
  systemd-pam-239-82.0.13.el8_10.17.x86_64                     systemd-udev-239-82.0.13.el8_10.17.x86_64              unbound-libs-1.16.2-5.14.el8_10.x86_64
Installed:
  kernel-4.18.0-553.156.1.el8_10.x86_64                   kernel-core-4.18.0-553.156.1.el8_10.x86_64                kernel-devel-4.18.0-553.156.1.el8_10.x86_64
  kernel-modules-4.18.0-553.156.1.el8_10.x86_64           kernel-uek-5.15.0-323.211.3.4.el8uek.x86_64               kernel-uek-core-5.15.0-323.211.3.4.el8uek.x86_64
  kernel-uek-devel-5.15.0-323.211.3.4.el8uek.x86_64       kernel-uek-modules-5.15.0-323.211.3.4.el8uek.x86_64       systemtap-sdt-devel-4.9-3.0.1.el8.x86_64

Complete!

6. Modify Configuration, Disable services required for installation.
#Setup the SELINUX to permissive
    set SELINUX to permissive
    vi /etc/selinux/config

#Disable few required services
[root@caoradb02 rpm]# systemctl stop firewalld.service
[root@caoradb02 rpm]# systemctl disable firewalld.service
Removed /etc/systemd/system/multi-user.target.wants/firewalld.service.
Removed /etc/systemd/system/dbus-org.fedoraproject.FirewallD1.service.


[root@caoradb02 rpm]# systemctl stop chronyd.service
[root@caoradb02 rpm]# systemctl disable chronyd.service
Removed /etc/systemd/system/multi-user.target.wants/chronyd.service.

#Need to create symbolic link if we are going to run cluster verification script with sudo privileges.
[root@caoradb02 rpm]# ln -s /usr/bin/sudo /usr/local/bin/sudo

#Set NOZEROCONF to yes 
vi /etc/sysconfig/network
NOZEROCONF=yes

7. Reboot the server

8. Update the .bash_profile and grid_env Grid environmental variable file.
# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

#Oracle Settings
TMP=/tmp; export TMP
TMPDIR=$TMP; export TMPDIR

ORACLE_BASE=/u01/app/oracle; export ORACLE_BASE
GRID_HOME=/u01/app/19.3.0/grid; export GRID_HOME
DB_HOME=/u01/app/19.3.0/db; export DB_HOME
ORACLE_HOME=$DB_HOME; export ORACLE_HOME
#ORACLE_SID=QA; export ORACLE_SID
ORACLE_TERM=xterm; export ORACLE_TERM
BASE_PATH=/usr/sbin:$PATH; export BASE_PATH
PATH=$ORACLE_HOME/bin:$BASE_PATH; export PATH

LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib; export LD_LIBRARY_PATH
CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib; export CLASSPATH


vi grid_env
ORACLE_SID=+ASM; export ORACLE_SID
ORACLE_HOME=$GRID_HOME; export ORACLE_HOME
PATH=$ORACLE_HOME/bin:$BASE_PATH; export PATH

LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib; export LD_LIBRARY_PATH
CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib; export CLASSPATH



******************************************************************************************************************************************************************
                                                                     ASM Setup
******************************************************************************************************************************************************************
9. Configure ASM as 'root' user

lsblk

#Partition the disk for the ASM
[root@caoradb02 ~]# parted /dev/sdb --script -a optimal mklabel gpt mkpart primary 0% 100%

#Configure ASM as 'root' user. 
[root@caoradb02 ~]# oracleasm configure -i
Configuring the Oracle ASM system service.

This will configure the on-boot properties of the Oracle ASM system
service.  The following questions will determine whether the service
is started on boot and what permissions it will have.  The current
values will be shown in brackets ('[]').  Hitting <ENTER> without
typing an answer will keep that current value.  Ctrl-C will abort.

Default user to own the ASM disk devices []: oracle
Default group to own the ASM disk devices []: oinstall
Start Oracle ASM system service on boot (y/n) [y]: y
Scan for Oracle ASM disks when starting the oracleasm service (y/n) [y]: y
Maximum number of ASM disks that can be used on system [2048]:
Enable iofilter if kernel supports it (y/n) [y]: y
Writing Oracle ASM system service configuration: done

Configuration changes only come into effect after the Oracle ASM
system service is restarted.  Please run 'systemctl restart oracleasm'
after making changes.

WARNING: All of your Oracle and ASM instances must be stopped prior
to restarting the oracleasm service.

#Restart ASM service - This is new from oracleasm3.0
[root@caoradb02 ~]# systemctl restart oracleasm

#Check ASM Status 
[root@caoradb02 ~]# oracleasm status
Checking if the oracleasm kernel module is loaded: no (not required with UEK7)
Checking if /dev/oracleasm is mounted: no (not required with UEK7)
Checking which I/O Interface is in use: io_uring (KABI_V3)
Checking if ASMLIB can be loaded: yes
Checking if io_uring is enabled: yes
Checking if io_uring is accessible to the configured DB user: yes
Checking if io_uring supports integrity passthrough: no
Checking if ASM disks have the correct ownership and permissions: yes
Checking if ASM I/O filter is set up: yes

#Initialize ASM
[root@caoradb02 ~]# oracleasm init
Mounting oracleasm driver filesystem: Not applicable with UEK7
Reloading disk partitions: done
Cleaning any stale ASM disks...
Setting up iofilter map for ASM disks: done
Scanning system for ASM disks...
Disk scan successful

#To Start installation we have to first create ASM Disk for Voting Disk as 'root' user
[root@caoradb02 ~]# oracleasm createdisk VOTK /dev/sdb1
Writing disk header: done
Instantiating disk: done

[root@caoradb02 ~]# oracleasm scandisks
Reloading disk partitions: done
Cleaning any stale ASM disks...
Setting up iofilter map for ASM disks: done
Scanning system for ASM disks...

#From oraclasm3.0 the default path for oracleasm disk from /dev/disk/oracleasm/* to /dev/disk/by-label/*
[root@caoradb02 ~]# oracleasm listdisks
VOTK
[root@caoradb02 ~]# ls -l /dev/disk/by-label/VOTK
lrwxrwxrwx. 1 root root 10 Aug 22 06:53 /dev/disk/by-label/VOTK -> ../../sdb1


******************************************************************************************************************************************************
															Grid Installation
******************************************************************************************************************************************************
10. Grid Installation

(a). Set the environment to OEL8.10
[oracle@caoradb02 software]$ export CV_ASSUME_DISTID=OEL8.10

(b). Run the cluster verification utility before installing Grid Software.
[oracle@caoradb02 software]$ /u01/app/19.3.0/grid/runcluvfy.sh stage -pre hacfg

Verifying Physical Memory ...PASSED
Verifying Available Physical Memory ...PASSED
Verifying Swap Size ...PASSED
Verifying Free Space: caoradb02:/usr,caoradb02:/var,caoradb02:/etc,caoradb02:/sbin,caoradb02:/tmp ...PASSED
Verifying User Existence: oracle ...
  Verifying Users With Same UID: 501 ...PASSED
Verifying User Existence: oracle ...PASSED
Verifying Group Existence: dba ...PASSED
Verifying Group Existence: oinstall ...PASSED
Verifying Group Membership: oinstall(Primary) ...PASSED
Verifying Group Membership: dba ...PASSED
Verifying Run Level ...PASSED
Verifying Users With Same UID: 0 ...PASSED
Verifying Current Group ID ...PASSED
Verifying Root user consistency ...PASSED

Pre-check for Oracle Restart configuration was successful.

CVU operation performed:      stage -pre hacfg
Date:                         Aug 22, 2026 6:55:47 AM
CVU home:                     /u01/app/19.3.0/grid/
User:                         oracle

(c). Cluster verification script with sudo privileges
[oracle@caoradb02 software]$ /u01/app/19.3.0/grid/runcluvfy.sh stage -pre crsinst -n caoradb02 -verbose -method sudo -user oracle
Enter "SUDO" password:

Verifying Physical Memory ...
  Node Name     Available                 Required                  Status
  ------------  ------------------------  ------------------------  ----------
  caoradb02     31.0555GB (3.2564092E7KB)  8GB (8388608.0KB)         passed
Verifying Physical Memory ...PASSED
Verifying Available Physical Memory ...
  Node Name     Available                 Required                  Status
  ------------  ------------------------  ------------------------  ----------
  caoradb02     30.3041GB (3.177616E7KB)  50MB (51200.0KB)          passed
Verifying Available Physical Memory ...PASSED
Verifying Swap Size ...
  Node Name     Available                 Required                  Status
  ------------  ------------------------  ------------------------  ----------
  caoradb02     16GB (1.6777212E7KB)      16GB (1.6777216E7KB)      passed
Verifying Swap Size ...PASSED
Verifying Free Space: caoradb02:/usr,caoradb02:/var,caoradb02:/etc,caoradb02:/sbin,caoradb02:/tmp ...
  Path              Node Name     Mount point   Available     Required      Status
  ----------------  ------------  ------------  ------------  ------------  ------------
  /usr              caoradb02     /             46.5322GB     25MB          passed
  /var              caoradb02     /             46.5322GB     5MB           passed
  /etc              caoradb02     /             46.5322GB     25MB          passed
  /sbin             caoradb02     /             46.5322GB     10MB          passed
  /tmp              caoradb02     /             46.5322GB     1GB           passed
Verifying Free Space: caoradb02:/usr,caoradb02:/var,caoradb02:/etc,caoradb02:/sbin,caoradb02:/tmp ...PASSED
Verifying User Existence: oracle ...
  Node Name     Status                    Comment
  ------------  ------------------------  ------------------------
  caoradb02     passed                    exists(501)

  Verifying Users With Same UID: 501 ...PASSED
Verifying User Existence: oracle ...PASSED
Verifying Group Existence: asmadmin ...
  Node Name     Status                    Comment
  ------------  ------------------------  ------------------------
  caoradb02     passed                    exists
Verifying Group Existence: asmadmin ...PASSED
Verifying Group Existence: asmdba ...
  Node Name     Status                    Comment
  ------------  ------------------------  ------------------------
  caoradb02     passed                    exists
Verifying Group Existence: asmdba ...PASSED
Verifying Group Existence: oinstall ...
  Node Name     Status                    Comment
  ------------  ------------------------  ------------------------
  caoradb02     passed                    exists
Verifying Group Existence: oinstall ...PASSED
Verifying Group Membership: asmadmin ...
  Node Name         User Exists   Group Exists  User in Group  Status
  ----------------  ------------  ------------  ------------  ----------------
  caoradb02         yes           yes           yes           passed
Verifying Group Membership: asmadmin ...PASSED
Verifying Group Membership: asmdba ...
  Node Name         User Exists   Group Exists  User in Group  Status
  ----------------  ------------  ------------  ------------  ----------------
  caoradb02         yes           yes           yes           passed
Verifying Group Membership: asmdba ...PASSED
Verifying Group Membership: oinstall(Primary) ...
  Node Name         User Exists   Group Exists  User in Group  Primary       Status
  ----------------  ------------  ------------  ------------  ------------  ------------
  caoradb02         yes           yes           yes           yes           passed
Verifying Group Membership: oinstall(Primary) ...PASSED
Verifying Run Level ...
  Node Name     run level                 Required                  Status
  ------------  ------------------------  ------------------------  ----------
  caoradb02     3                         3,5                       passed
Verifying Run Level ...PASSED
Verifying Users With Same UID: 0 ...PASSED
Verifying Current Group ID ...PASSED
Verifying Root user consistency ...
  Node Name                             Status
  ------------------------------------  ------------------------
  caoradb02                             passed
Verifying Root user consistency ...PASSED
Verifying Package: cvuqdisk-1.0.10-1 ...
  Node Name     Available                 Required                  Status
  ------------  ------------------------  ------------------------  ----------
  caoradb02     cvuqdisk-1.0.10-1         cvuqdisk-1.0.10-1         passed
Verifying Package: cvuqdisk-1.0.10-1 ...PASSED
Verifying Host name ...PASSED
Verifying Node Connectivity ...
  Verifying Hosts File ...
  Node Name                             Status
  ------------------------------------  ------------------------
  caoradb02                             passed
  Verifying Hosts File ...PASSED

Interface information for node "caoradb02"

 Name   IP Address      Subnet          Gateway         Def. Gateway    HW Address        MTU
 ------ --------------- --------------- --------------- --------------- ----------------- ------
 ens3   10.0.0.119      10.0.0.0        0.0.0.0         10.0.0.1        02:00:17:01:B2:1C 9000

Check: MTU consistency of the subnet "10.0.0.0".

  Node              Name          IP Address    Subnet        MTU
  ----------------  ------------  ------------  ------------  ----------------
  caoradb02         ens3          10.0.0.119    10.0.0.0      9000
  Verifying Check that maximum (MTU) size packet goes through subnet ...PASSED
Verifying Node Connectivity ...PASSED
Verifying Multicast or broadcast check ...
Checking subnet "10.0.0.0" for multicast communication with multicast group "224.0.0.251"
Verifying Multicast or broadcast check ...PASSED
Verifying ASMLib installation and configuration verification. ...
  Verifying '/etc/init.d/oracleasm' ...PASSED
  Verifying '/dev/oracleasm' ...PASSED

  Node Name                             Status
  ------------------------------------  ------------------------
  caoradb02                             passed
Verifying ASMLib installation and configuration verification. ...PASSED
Verifying Network Time Protocol (NTP) ...PASSED
Verifying Same core file name pattern ...PASSED
Verifying User Mask ...
  Node Name     Available                 Required                  Comment
  ------------  ------------------------  ------------------------  ----------
  caoradb02     0022                      0022                      passed
Verifying User Mask ...PASSED
Verifying User Not In Group "root": oracle ...
  Node Name     Status                    Comment
  ------------  ------------------------  ------------------------
  caoradb02     passed                    does not exist
Verifying User Not In Group "root": oracle ...PASSED
Verifying Time zone consistency ...PASSED
Verifying resolv.conf Integrity ...
  Node Name                             Status
  ------------------------------------  ------------------------
  caoradb02                             passed

checking response for name "caoradb02" from each of the name servers specified
in "/etc/resolv.conf"

  Node Name     Source                    Comment                   Status
  ------------  ------------------------  ------------------------  ----------
  caoradb02     169.254.169.254           IPv4                      passed
Verifying resolv.conf Integrity ...PASSED
Verifying DNS/NIS name service ...PASSED
Verifying Domain Sockets ...PASSED
Verifying /boot mount ...PASSED
Verifying Daemon "avahi-daemon" not configured and running ...
  Node Name     Configured                Status
  ------------  ------------------------  ------------------------
  caoradb02     no                        passed

  Node Name     Running?                  Status
  ------------  ------------------------  ------------------------
  caoradb02     no                        passed
Verifying Daemon "avahi-daemon" not configured and running ...PASSED
Verifying Daemon "proxyt" not configured and running ...
  Node Name     Configured                Status
  ------------  ------------------------  ------------------------
  caoradb02     no                        passed

  Node Name     Running?                  Status
  ------------  ------------------------  ------------------------
  caoradb02     no                        passed
Verifying Daemon "proxyt" not configured and running ...PASSED
Verifying User Equivalence ...PASSED
Verifying RPM Package Manager database ...PASSED
Verifying /dev/shm mounted as temporary file system ...PASSED
Verifying File system mount options for path /var ...PASSED
Verifying DefaultTasksMax parameter ...PASSED
Verifying zeroconf check ...PASSED
Verifying ASM Filter Driver configuration ...PASSED

Pre-check for cluster services setup was successful.

CVU operation performed:      stage -pre crsinst
Date:                         Aug 22, 2026 6:55:55 AM
CVU home:                     /u01/app/19.3.0/grid/
User:                         oracle

(d). Taking the backup of existing response file before modification.

ls -lrth /u01/app/19.3.0/grid/install/response/gridsetup.rsp


cp -prf /u01/app/19.3.0/grid/install/response/gridsetup.rsp /u01/app/oracle/software/gridSetup.rsp
vi /u01/app/oracle/software/gridSetup.rsp

(e). Modify the response file

oracle.install.responseFileVersion=/oracle/install/rspfmt_crsinstall_response_schema_v19.0.0
INVENTORY_LOCATION=/u01/app/oraInventory
oracle.install.option=HA_CONFIG
ORACLE_BASE=/u01/app/oracle
oracle.install.asm.OSDBA=oinstall
oracle.install.asm.OSOPER=oinstall
oracle.install.asm.OSASM=oinstall
oracle.install.crs.config.scanType=LOCAL_SCAN
oracle.install.crs.config.ClusterConfiguration=STANDALONE
oracle.install.crs.config.configureAsExtendedCluster=false
oracle.install.crs.config.gpnp.configureGNS=false
oracle.install.crs.config.autoConfigureClusterNodeVIP=false
oracle.install.crs.config.gpnp.gnsOption=CREATE_NEW_GNS
oracle.install.crs.configureGIMR=false
oracle.install.asm.configureGIMRDataDG=false
oracle.install.crs.config.useIPMI=false
oracle.install.asm.SYSASMPassword=***********
oracle.install.asm.diskGroup.name=VOTK
oracle.install.asm.diskGroup.redundancy=EXTERNAL
oracle.install.asm.diskGroup.AUSize=4
oracle.install.asm.diskGroup.disks=/dev/disk/by-label/VOTK
oracle.install.asm.diskGroup.diskDiscoveryString=/dev/disk/by-label/*
oracle.install.asm.monitorPassword=***************
oracle.install.asm.configureAFD=false
oracle.install.crs.configureRHPS=false
oracle.install.crs.config.ignoreDownNodes=false
oracle.install.config.managementOption=NONE
oracle.install.crs.rootconfig.executeRootScript=false


(f). We have downloaded 19.3.0 software binaries. Now we are going to install the software installation.
[oracle@caoradb02 ~]$ /u01/app/19.3.0/grid/gridSetup.sh -ignorePrereq -silent -responseFile /u01/app/oracle/software/gridSetup.rsp
Launching Oracle Grid Infrastructure Setup Wizard...

The response file for this session can be found at:
 /u01/app/19.3.0/grid/install/response/grid_2026-08-22_06-57-59AM.rsp

You can find the log of this install session at:
 /tmp/GridSetupActions2026-08-22_06-57-59AM/gridSetupActions2026-08-22_06-57-59AM.log

As a root user, execute the following script(s):
        1. /u01/app/oraInventory/orainstRoot.sh
        2. /u01/app/19.3.0/grid/root.sh

Execute /u01/app/19.3.0/grid/root.sh on the following nodes:
[caoradb02]



Successfully Setup Software.
As install user, execute the following command to complete the configuration.
        /u01/app/19.3.0/grid/gridSetup.sh -executeConfigTools -responseFile /u01/app/oracle/software/gridSetup.rsp [-silent]


Moved the install session logs to:
 /u01/app/oraInventory/logs/GridSetupActions2026-08-22_06-57-59AM

#orainstRoot.sh log file
[root@caoradb02 ~]# /u01/app/oraInventory/orainstRoot.sh
Changing permissions of /u01/app/oraInventory.
Adding read,write permissions for group.
Removing read,write,execute permissions for world.

Changing groupname of /u01/app/oraInventory to oinstall.
The execution of the script is complete.
[root@caoradb02 ~]# /u01/app/19.3.0/grid/root.sh
Check /u01/app/19.3.0/grid/install/root_caoradb02_2026-08-22_06-59-45-204927973.log for the output of root script

#root.sh log file
[root@caoradb02 ~]# cat /u01/app/19.3.0/grid/install/root_caoradb02_2026-08-22_06-59-45-204927973.log
Performing root user operation.

The following environment variables are set as:
    ORACLE_OWNER= oracle
    ORACLE_HOME=  /u01/app/19.3.0/grid
   Copying dbhome to /usr/local/bin ...
   Copying oraenv to /usr/local/bin ...
   Copying coraenv to /usr/local/bin ...


Creating /etc/oratab file...
Entries will be added to the /etc/oratab file as needed by
Database Configuration Assistant when a database is created
Finished running generic part of root script.
Now product-specific root actions will be performed.
Using configuration parameter file: /u01/app/19.3.0/grid/crs/install/crsconfig_params
The log of current session can be found at:
  /u01/app/oracle/crsdata/caoradb02/crsconfig/roothas_2026-08-22_06-59-45AM.log
2026/08/22 06:59:56 CLSRSC-363: User ignored prerequisites during installation
LOCAL ADD MODE
Creating OCR keys for user 'oracle', privgrp 'oinstall'..
Operation successful.
LOCAL ONLY MODE
Successfully accumulated necessary OCR keys.
Creating OCR keys for user 'root', privgrp 'root'..
Operation successful.
CRS-4664: Node caoradb02 successfully pinned.
2026/08/22 07:00:04 CLSRSC-330: Adding Clusterware entries to file 'oracle-ohasd.service'

caoradb02     2026/08/22 07:00:45     /u01/app/oracle/crsdata/caoradb02/olr/backup_20260822_070045.olr     724960844
2026/08/22 07:00:45 CLSRSC-327: Successfully configured Oracle Restart for a standalone server


#Proceed with the final Grid Infrastructure configuration step by running the Config Tools, which are responsible for creating the ASM instance and the Voting Disk Group.
#This stage is particularly critical when using base release 19.3.0 together with oracleasmlib versions later than 3.0, because this is where the ASM instance is initialized and the ASM Disk Group creation begins.
#During this phase, the ASM instance is briefly created and appears in the cluster services, with its state transitioning to STARTING. However, as soon as the installer attempts to create the ASM Disk Group, the ASM setup fails. Once the disk group creation fails, Grid Infrastructure automatically cleans up by stopping the ASM instance and removing its service entry from the cluster.

[oracle@caoradb02 ~]$ /u01/app/19.3.0/grid/gridSetup.sh -executeConfigTools -responseFile /u01/app/oracle/software/gridSetup.rsp -silent
Launching Oracle Grid Infrastructure Setup Wizard...

You can find the logs of this session at:
/u01/app/oraInventory/logs/GridSetupActions2026-08-22_07-01-03AM

You can find the log of this install session at:
 /u01/app/oraInventory/logs/UpdateNodeList2026-08-22_07-01-03AM.log
[WARNING] [INS-43080] Some of the configuration assistants failed, were cancelled or skipped.
   ACTION: Refer to the logs or contact Oracle Support Services.

[root@caoradb02 trace]# /u01/app/19.3.0/grid/bin/crsctl stat res -init -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       caoradb02                STABLE
ora.asm
               OFFLINE ONLINE       caoradb02                Started,STOPPING
ora.ons
               OFFLINE OFFLINE      caoradb02                STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.cssd
      1        ONLINE  ONLINE       caoradb02                STABLE
ora.diskmon
      1        OFFLINE OFFLINE                               STABLE
ora.evmd
      1        ONLINE  ONLINE       caoradb02                STABLE
--------------------------------------------------------------------------------

[root@caoradb02 ~]# /u01/app/19.3.0/grid/bin/crsctl stat res -init -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       caoradb02                STABLE
ora.asm
               OFFLINE OFFLINE      caoradb02                Instance Shutdown,ST
                                                             ABLE
ora.ons
               OFFLINE OFFLINE      caoradb02                STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.cssd
      1        ONLINE  ONLINE       caoradb02                STABLE
ora.diskmon
      1        OFFLINE OFFLINE                               STABLE
ora.evmd
      1        ONLINE  ONLINE       caoradb02                STABLE


[root@caoradb02 OPatch]# /u01/app/19.3.0/grid/bin/crsctl stat res -init -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       caoradb02                STABLE
ora.ons
               OFFLINE OFFLINE      caoradb02                STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.cssd
      1        OFFLINE OFFLINE                               STABLE
ora.diskmon
      1        OFFLINE OFFLINE                               STABLE
ora.evmd
      1        ONLINE  ONLINE       caoradb02                STABLE

#Error Message [WARNING] [INS-43080]:
[root@caoradb02 GridSetupActions2026-08-22_07-01-03AM]# vi gridSetupActions2026-08-22_07-01-03AM.log
[root@caoradb02 GridSetupActions2026-08-22_07-01-03AM]#

INFO:  [Aug 22, 2026 7:01:59 AM] [FATAL] [DBT-30002] Disk group VOT creation failed.
INFO:  [Aug 22, 2026 7:01:59 AM] Skipping line: [FATAL] [DBT-30002] Disk group VOT creation failed.
INFO:  [Aug 22, 2026 7:01:59 AM] ORA-15018: diskgroup cannot be created
INFO:  [Aug 22, 2026 7:01:59 AM] Skipping line: ORA-15018: diskgroup cannot be created

WARNING:  [Aug 22, 2026 7:01:59 AM] [WARNING] [INS-43080] Some of the configuration assistants failed, were cancelled or skipped.
   ACTION: Refer to the logs or contact Oracle Support Services.


**********************************************************************************************************************************************************************
                                                                      Patching Grid Home 19.3.0 -> 19.32.0
**********************************************************************************************************************************************************************

11. Grid Patching

#Workaround for this issue 
#1. Patch 19.3.0 to the latest CPU 19.32.0
#2. Create ASM Instance with Diskgroup creation

(a). OPatch must be updated to version 12.2.0.1.52 prior to applying the latest CPU 19.32.0.
[root@caoradb02 ~]# cd /u01/app/19.3.0/grid/
[root@caoradb02 grid]# mv OPatch OPatch_12.2.0.1.17
[root@caoradb02 grid]# unzip -q /u01/app/oracle/software/p6880880_190000_Linux-x86-64.zip -d /u01/app/19.3.0/grid/
[root@caoradb02 grid]# chmod 755 -R /u01/app/19.3.0/grid/OPatch
[root@caoradb02 grid]# chown oracle:oinstall -R /u01/app/19.3.0/grid/OPatch
[root@caoradb02 grid]# /u01/app/19.3.0/grid/OPatch/opatch version
OPatch Version: 12.2.0.1.52

OPatch succeeded.

(b). Download July2026 CPU and unzip the package
[oracle@caoradb02 software]$ unzip -q p39467003_190000_Linux-x86-64.zip


(c). Check Patch Conflicts
$ORACLE_HOME/OPatch/opatch prereq CheckMinimumOPatchVersion -phBaseDir /u01/app/oracle/software/39472050
$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /u01/app/oracle/software/39467003/39472050
$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /u01/app/oracle/software/39467003/39526364
$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /u01/app/oracle/software/39467003/39503034
$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /u01/app/oracle/software/39467003/39107855
$ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir /u01/app/oracle/software/39467003/39107825

(d). Apply 19.32.0 RU on 19.3.0 Grid Home using opatchauto
[root@caoradb02 OPatch]# /u01/app/19.3.0/grid/OPatch/opatchauto apply /u01/app/oracle/software/39467003 -analyze

OPatchauto session is initiated at Sat Aug 22 07:07:10 2026

System initialization log file is /u01/app/19.3.0/grid/cfgtoollogs/opatchautodb/systemconfig2026-08-22_07-07-20AM.log.

Session log file is /u01/app/19.3.0/grid/cfgtoollogs/opatchauto/opatchauto2026-08-22_07-07-25AM.log
The id for this session is CWX4

Executing OPatch prereq operations to verify patch applicability on home /u01/app/19.3.0/grid
Patch applicability verified successfully on home /u01/app/19.3.0/grid


Executing patch validation checks on home /u01/app/19.3.0/grid
Patch validation checks successfully completed on home /u01/app/19.3.0/grid

OPatchAuto successful.

--------------------------------Summary--------------------------------

Analysis for applying patches has completed successfully:

Host:caoradb02
SIHA Home:/u01/app/19.3.0/grid
Version:19.0.0.0.0


==Following patches were SUCCESSFULLY analyzed to be applied:

Patch: /u01/app/oracle/software/39467003/39526364
Log: /u01/app/19.3.0/grid/cfgtoollogs/opatchauto/core/opatch/opatch2026-08-22_07-07-54AM_1.log

Patch: /u01/app/oracle/software/39467003/39503034
Log: /u01/app/19.3.0/grid/cfgtoollogs/opatchauto/core/opatch/opatch2026-08-22_07-07-54AM_1.log

Patch: /u01/app/oracle/software/39467003/39107825
Log: /u01/app/19.3.0/grid/cfgtoollogs/opatchauto/core/opatch/opatch2026-08-22_07-07-54AM_1.log

Patch: /u01/app/oracle/software/39467003/39107855
Log: /u01/app/19.3.0/grid/cfgtoollogs/opatchauto/core/opatch/opatch2026-08-22_07-07-54AM_1.log

Patch: /u01/app/oracle/software/39467003/39472050
Log: /u01/app/19.3.0/grid/cfgtoollogs/opatchauto/core/opatch/opatch2026-08-22_07-07-54AM_1.log



OPatchauto session completed at Sat Aug 22 07:09:52 2026
Time taken to complete the session 2 minutes, 32 seconds
[root@caoradb02 OPatch]# /u01/app/19.3.0/grid/OPatch/opatchauto apply /u01/app/oracle/software/39467003

OPatchauto session is initiated at Sat Aug 22 07:10:01 2026

System initialization log file is /u01/app/19.3.0/grid/cfgtoollogs/opatchautodb/systemconfig2026-08-22_07-10-10AM.log.

Session log file is /u01/app/19.3.0/grid/cfgtoollogs/opatchauto/opatchauto2026-08-22_07-10-13AM.log
The id for this session is B1BN

Executing OPatch prereq operations to verify patch applicability on home /u01/app/19.3.0/grid
Patch applicability verified successfully on home /u01/app/19.3.0/grid


Executing patch validation checks on home /u01/app/19.3.0/grid
Patch validation checks successfully completed on home /u01/app/19.3.0/grid


Performing prepatch operations on CRS - bringing down CRS service on home /u01/app/19.3.0/grid
Prepatch operation log file location: /u01/app/oracle/crsdata/caoradb02/crsconfig/hapatch_2026-08-22_07-12-41AM.log
CRS service brought down successfully on home /u01/app/19.3.0/grid


Start applying binary patch on home /u01/app/19.3.0/grid
Binary patch applied successfully on home /u01/app/19.3.0/grid


Running rootadd_rdbms.sh on home /u01/app/19.3.0/grid
Successfully executed rootadd_rdbms.sh on home /u01/app/19.3.0/grid




Performing postpatch operations on CRS - starting CRS service on home /u01/app/19.3.0/grid
Postpatch operation log file location: /u01/app/oracle/crsdata/caoradb02/crsconfig/hapatch_2026-08-22_07-30-16AM.log
CRS service started successfully on home /u01/app/19.3.0/grid

OPatchAuto successful.

--------------------------------Summary--------------------------------

Patching is completed successfully. Please find the summary as follows:

Host:caoradb02
SIHA Home:/u01/app/19.3.0/grid
Version:19.0.0.0.0
Summary:

==Following patches were SUCCESSFULLY applied:

Patch: /u01/app/oracle/software/39467003/39107825
Log: /u01/app/19.3.0/grid/cfgtoollogs/opatchauto/core/opatch/opatch2026-08-22_07-12-57AM_1.log

Patch: /u01/app/oracle/software/39467003/39107855
Log: /u01/app/19.3.0/grid/cfgtoollogs/opatchauto/core/opatch/opatch2026-08-22_07-12-57AM_1.log

Patch: /u01/app/oracle/software/39467003/39472050
Log: /u01/app/19.3.0/grid/cfgtoollogs/opatchauto/core/opatch/opatch2026-08-22_07-12-57AM_1.log

Patch: /u01/app/oracle/software/39467003/39503034
Log: /u01/app/19.3.0/grid/cfgtoollogs/opatchauto/core/opatch/opatch2026-08-22_07-12-57AM_1.log

Patch: /u01/app/oracle/software/39467003/39526364
Log: /u01/app/19.3.0/grid/cfgtoollogs/opatchauto/core/opatch/opatch2026-08-22_07-12-57AM_1.log



OPatchauto session completed at Sat Aug 22 07:30:59 2026
Time taken to complete the session 20 minutes, 50 seconds


12. Check the cluster installation status as 'root' user

[root@caoradb02 OPatch]# /u01/app/19.3.0/grid/bin/crsctl stat res -init -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       caoradb02                STABLE
ora.ons
               OFFLINE OFFLINE      caoradb02                STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.cssd
      1        OFFLINE OFFLINE                               STABLE
ora.diskmon
      1        OFFLINE OFFLINE                               STABLE
ora.evmd
      1        ONLINE  ONLINE       caoradb02                STABLE


13. Create ASM Instance
#Now create ASM Instance. ASM instance will be created, Diskgroup will be created and ASM will be STARTED.
[oracle@caoradb02 ~]$ asmca -silent \
>   -configureASM \
>   -sysAsmPassword "*******************" \
>   -asmMonitorPassword "*******************" \
>   -diskString 'ORCL:*,/dev/disk/by-label/*' \
>   -diskGroupName VOTK \
>   -diskList 'ORCL:VOTK' \
>   -redundancy EXTERNAL \
>   -au_size 4

ASM has been created and started successfully.

[DBT-30001] Disk groups created successfully. Check /u01/app/oracle/cfgtoollogs/asmca/asmca-260822AM073300.log for details.

14. Check the cluster installation status as 'root' user

[root@caoradb02 OPatch]# /u01/app/19.3.0/grid/bin/crsctl stat res -init -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       caoradb02                STABLE
ora.asm
               ONLINE  OFFLINE      caoradb02                STARTING
ora.ons
               OFFLINE OFFLINE      caoradb02                STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.cssd
      1        ONLINE  ONLINE       caoradb02                STABLE
ora.diskmon
      1        OFFLINE OFFLINE                               STABLE
ora.evmd
      1        ONLINE  ONLINE       caoradb02                STABLE
--------------------------------------------------------------------------------

[root@caoradb02 OPatch]# /u01/app/19.3.0/grid/bin/crsctl stat res -init -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.LISTENER.lsnr
               ONLINE  ONLINE       caoradb02                STABLE
ora.VOTK.dg
               ONLINE  ONLINE       caoradb02                STABLE
ora.asm
               ONLINE  ONLINE       caoradb02                Started,STABLE
ora.ons
               OFFLINE OFFLINE      caoradb02                STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.cssd
      1        ONLINE  ONLINE       caoradb02                STABLE
ora.diskmon
      1        OFFLINE OFFLINE                               STABLE
ora.evmd
      1        ONLINE  ONLINE       caoradb02                STABLE
--------------------------------------------------------------------------------


15. Creating few other ASM Disks, Disk Groups
#Now we have successfully create the ASM instance and ASM Diskgroup. We will continue creating other diskgroups
(a). Check if ASM is running to continue with database installation.
ps -ef | grep pmon

(b). Create partitions for different ASM Disks as 'root' user

[root@caoradb02 ~]# parted /dev/sdc --script -a optimal mklabel gpt mkpart primary 0% 100%
[root@caoradb02 ~]# parted /dev/sdd --script -a optimal mklabel gpt mkpart primary 0% 100%
[root@caoradb02 ~]# parted /dev/sde --script -a optimal mklabel gpt mkpart primary 0% 100%

(c). Creating ASM Disks as 'root' user
[root@caoradb02 ~]# oracleasm createdisk DATA /dev/sdc1
Writing disk header: done
Instantiating disk: done

[root@caoradb02 ~]# oracleasm createdisk REDO /dev/sdd1
Writing disk header: done
Instantiating disk: done

[root@caoradb02 ~]# oracleasm createdisk FRA /dev/sde1
Writing disk header: done
Instantiating disk: done

(d). Scanning ASM Disks
[root@caoradb02 ~]# oracleasm scandisks
Reloading disk partitions: done
Cleaning any stale ASM disks...
Setting up iofilter map for ASM disks: done
Scanning system for ASM disks...

(e). List ASM Disks
[root@caoradb02 ~]# oracleasm listdisks
DATA
FRA
REDO
VOTK

16. Creating other ASM Diskgroups using asmca in silent mode.
#Set Grid environmental variables by setting ORACLE_HOME=<GRID_HOME> and ORACLE_SID=+ASM

[oracle@ociporadb ~]$ asmca -silent -createDiskGroup -diskString 'ORCL:*' -diskGroupName DATA -diskList 'ORCL:DATA' -redundancy EXTERNAL

[DBT-30001] Disk groups created successfully. Check /u01/app/oracle/cfgtoollogs/asmca/asmca-260804AM060117.log for details.

[oracle@caoradb02 ~]$ asmca -silent -createDiskGroup -diskString 'ORCL:*' -diskGroupName DATA -diskList 'ORCL:DATA' -redundancy EXTERNAL

[DBT-30001] Disk groups created successfully. Check /u01/app/oracle/cfgtoollogs/asmca/asmca-260826AM044250.log for details.

[oracle@caoradb02 ~]$ asmca -silent -createDiskGroup -diskString 'ORCL:*' -diskGroupName REDO -diskList 'ORCL:REDO' -redundancy EXTERNAL

[DBT-30001] Disk groups created successfully. Check /u01/app/oracle/cfgtoollogs/asmca/asmca-260826AM044312.log for details.

[oracle@caoradb02 ~]$ asmca -silent -createDiskGroup -diskString 'ORCL:*' -diskGroupName FRA -diskList 'ORCL:FRA' -redundancy EXTERNAL

[DBT-30001] Disk groups created successfully. Check /u01/app/oracle/cfgtoollogs/asmca/asmca-260826AM044343.log for details.

**********************************************************************************************************************************************************************
                                                                        Database installation
**********************************************************************************************************************************************************************

17. Unzip Database Software to Database Home Directory as 'oracle' user

cd /u01/app/oracle/software
[oracle@caoradb02 software]$ unzip -q /u01/app/oracle/software/V982063-01.zip -d /u01/app/19.3.0/db

18. To Start Database Installation in silent mode we have to first modify the response file as 'oracle' user

(a). Taking the backup of existing response file before modification.

ls -lrth /u01/app/19.3.0/db/install/response/db_install.rsp

cp -prf /u01/app/19.3.0/db/install/response/db_install.rsp /u01/app/oracle/software/db_install.rsp

(b). Modify the response file

oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=/u01/app/oraInventory
ORACLE_HOME=/u01/app/19.3.0/db
ORACLE_BASE=/u01/app/oracle
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=oinstall
oracle.install.db.OSOPER_GROUP=dba
oracle.install.db.OSBACKUPDBA_GROUP=oinstall
oracle.install.db.OSDGDBA_GROUP=oinstall
oracle.install.db.OSKMDBA_GROUP=oinstall
oracle.install.db.OSRACDBA_GROUP=oinstall
oracle.install.db.rootconfig.executeRootScript=false
oracle.install.db.ConfigureAsContainerDB=false
oracle.install.db.config.starterdb.memoryOption=false
oracle.install.db.config.starterdb.installExampleSchemas=false
oracle.install.db.config.starterdb.managementOption=DEFAULT
oracle.install.db.config.starterdb.enableRecovery=false

19. Run prerequisites check as 'oracle' user

/u01/app/19.3.0/db/runInstaller -executePrereqs -silent -responseFile /u01/app/oracle/software/db_install.rsp

20. Start the Silent Database Installation using response file as root

(a). Database software installation as 'oracle' user

[oracle@caoradb02 ~]$ /u01/app/19.3.0/db/runInstaller -executePrereqs -silent -responseFile /u01/app/oracle/software/db_install.rsp
Launching Oracle Database Setup Wizard...

[oracle@caoradb02 ~]$ /u01/app/19.3.0/db/runInstaller -silent -responseFile /u01/app/oracle/software/db_install.rsp
Launching Oracle Database Setup Wizard...

[WARNING] [INS-08101] Unexpected error while executing the action at state: 'supportedOSCheck'
   CAUSE: No additional information available.
   ACTION: Contact Oracle Support Services or refer to the software manual.
   SUMMARY:
       - java.lang.NullPointerException
	   
(b). Install Database Software.

[oracle@caoradb02 ~]$ export CV_ASSUME_DISTID=OEL8.10
[oracle@caoradb02 ~]$ /u01/app/19.3.0/db/runInstaller -silent -responseFile /u01/app/oracle/software/db_install.rsp
Launching Oracle Database Setup Wizard...

The response file for this session can be found at:
 /u01/app/19.3.0/db/install/response/db_2026-08-26_04-55-11AM.rsp

You can find the log of this install session at:
 /u01/app/oraInventory/logs/InstallActions2026-08-26_04-55-11AM/installActions2026-08-26_04-55-11AM.log

As a root user, execute the following script(s):
        1. /u01/app/19.3.0/db/root.sh

Execute /u01/app/19.3.0/db/root.sh on the following nodes:
[caoradb02]


Successfully Setup Software.
[oracle@caoradb02 ~]$


(c). Execute root.sh as 'root' user

[root@caoradb02 ~]# /u01/app/19.3.0/db/root.sh
Check /u01/app/19.3.0/db/install/root_caoradb02_2026-08-26_04-56-46-896077897.log for the output of root script
[root@caoradb02 ~]#


**********************************************************************************************************************************************************************
                                                                      Patching Database Home 19.3.0 -> 19.32.0
**********************************************************************************************************************************************************************

21. Database Patching

#Database software is installed, now we have to patch it to latest PSU 19.32.0
cd /u01/app/oracle/software/39467003/39472050

[oracle@caoradb02 39472050]$ $ORACLE_HOME/OPatch/opatch apply
Oracle Interim Patch Installer version 12.2.0.1.52
Copyright (c) 2026, Oracle Corporation.  All rights reserved.


Oracle Home       : /u01/app/19.3.0/db
Central Inventory : /u01/app/oraInventory
   from           : /u01/app/19.3.0/db/oraInst.loc
OPatch version    : 12.2.0.1.52
OUI version       : 12.2.0.7.0
Log file location : /u01/app/19.3.0/db/cfgtoollogs/opatch/opatch2026-08-26_05-04-25AM_1.log

Verifying environment and performing prerequisite checks...

--------------------------------------------------------------------------------
Start OOP by Prereq process.
Launch OOP...

Oracle Interim Patch Installer version 12.2.0.1.52
Copyright (c) 2026, Oracle Corporation.  All rights reserved.


Oracle Home       : /u01/app/19.3.0/db
Central Inventory : /u01/app/oraInventory
   from           : /u01/app/19.3.0/db/oraInst.loc
OPatch version    : 12.2.0.1.52
OUI version       : 12.2.0.7.0
Log file location : /u01/app/19.3.0/db/cfgtoollogs/opatch/opatch2026-08-26_05-05-36AM_1.log

Verifying environment and performing prerequisite checks...
OPatch continues with these patches:   39472050

Do you want to proceed? [y|n]
y
User Responded with: Y
All checks passed.

Please shutdown Oracle instances running out of this ORACLE_HOME on the local system.
(Oracle Home = '/u01/app/19.3.0/db')


Is the local system ready for patching? [y|n]
y
User Responded with: Y
Backing up files...


22. Verify the Installed patches and inventory 
#Check the installed patches on DB Home
[oracle@caoradb02 ~]$ $ORACLE_HOME/OPatch/opatch lsinventory | grep -i applied
Patch  39472050     : applied on Wed Aug 26 05:10:38 GMT 2026
Patch  29585399     : applied on Thu Apr 18 07:21:33 GMT 2019

[oracle@caoradb02 ~]$ $ORACLE_HOME/OPatch/opatch lspatches
39472050;Database Release Update : 19.32.0.0.260721 (39472050)
29585399;OCW RELEASE UPDATE 19.3.0.0.0 (29585399)

OPatch succeeded.

23. Check the cluster installation status as 'root' user

[root@caoradb04 ~]# /u01/app/19.3.0/grid/bin/crsctl stat res -init -t
--------------------------------------------------------------------------------
Name           Target  State        Server                   State details
--------------------------------------------------------------------------------
Local Resources
--------------------------------------------------------------------------------
ora.DATA.dg
               ONLINE  ONLINE       caoradb04                STABLE
ora.FRA.dg
               ONLINE  ONLINE       caoradb04                STABLE
ora.LISTENER.lsnr
               ONLINE  ONLINE       caoradb04                STABLE
ora.REDO.dg
               ONLINE  ONLINE       caoradb04                STABLE
ora.VOT.dg
               ONLINE  ONLINE       caoradb04                STABLE
ora.asm
               ONLINE  ONLINE       caoradb04                Started,STABLE
ora.ons
               OFFLINE OFFLINE      caoradb04                STABLE
--------------------------------------------------------------------------------
Cluster Resources
--------------------------------------------------------------------------------
ora.cssd
      1        ONLINE  ONLINE       caoradb04                STABLE
ora.diskmon
      1        OFFLINE OFFLINE                               STABLE
ora.evmd
      1        ONLINE  ONLINE       caoradb04                STABLE
--------------------------------------------------------------------------------

24. Changing ASM Diskgroups database.compatible parameter to 19.0.0.0
(a). Check the database.compatible parameter to 19.0.0.0 from 10.1.0.0.0, otherwise the database installation would fail
#As oracle user by setting grid environment variables
[oracle@caoradb02 ~]$ asmcmd -p
ASMCMD [+] > lsattr -G VOTK -l
Name                           Value
access_control.enabled         FALSE
access_control.umask           066
appliance._partnering_type     GENERIC
ate_conversion_done            true
au_size                        4194304
cell.smart_scan_capable        FALSE
cell.sparse_dg                 allnonsparse
compatible.advm                19.0.0.0.0
compatible.asm                 19.0.0.0.0
compatible.rdbms               10.1.0.0.0
content.check                  FALSE

SQL>  column COMPATIBILITY format a30
column DATABASE_COMPATIBILITY format a30
set line 300
select name, state, ALLOCATION_UNIT_SIZE, COMPATIBILITY, DATABASE_COMPATIBILITY from  v$asm_diskgroup;

NAME                           STATE       ALLOCATION_UNIT_SIZE COMPATIBILITY                  DATABASE_COMPATIBILITY
------------------------------ ----------- -------------------- ------------------------------ ------------------------------
VOTK                           MOUNTED                  4194304 19.0.0.0.0                     10.1.0.0.0
DATA                           MOUNTED                  1048576 19.0.0.0.0                     10.1.0.0.0
REDO                           MOUNTED                  1048576 19.0.0.0.0                     10.1.0.0.0
FRA                            MOUNTED                  1048576 19.0.0.0.0                     10.1.0.0.0

(b). Changing the database.compatible parameter
ASMCMD [+] > setattr -G VOT compatible.rdbms 19.0.0.0.0
ASMCMD [+] > setattr -G DATA compatible.rdbms 19.0.0.0.0
ASMCMD [+] > setattr -G REDO compatible.rdbms 19.0.0.0.0
ASMCMD [+] > setattr -G FRA compatible.rdbms 19.0.0.0.0
ASMCMD [+] > exit

(c). After modification validate the changed value
SQL> conn /as sysasm
Connected.
SQL>  column COMPATIBILITY format a30
column DATABASE_COMPATIBILITY format a30
set line 300
select name, state, ALLOCATION_UNIT_SIZE, COMPATIBILITY, DATABASE_COMPATIBILITY from  v$asm_diskgroup;
SQL> SQL> SQL>
NAME                           STATE       ALLOCATION_UNIT_SIZE COMPATIBILITY                  DATABASE_COMPATIBILITY
------------------------------ ----------- -------------------- ------------------------------ ------------------------------
VOT                            MOUNTED                  4194304 19.0.0.0.0                     19.0.0.0.0
DATA                           MOUNTED                  1048576 19.0.0.0.0                     19.0.0.0.0
REDO                           MOUNTED                  1048576 19.0.0.0.0                     19.0.0.0.0
FRA                            MOUNTED                  1048576 19.0.0.0.0                     19.0.0.0.0

25. Database Creation

[oracle@caoradb02 ~]$   dbca -silent -createDatabase \
>     -gdbName TESTCDB \
>     -sid TESTCDB \
>     -responseFile NO_VALUE \
>     -databaseConfigType SI \
>     -dbOptions JSERVER:true,ORACLE_TEXT:false,IMEDIA:false,CWMLITE:false,SPATIAL:false,OMS:false,APEX:false,DV:false \
>     -createAsContainerDatabase true \
>     -numberOfPDBs 1 \
>     -pdbName TESTPDB \
>     -pdbAdminPassword E4CQmk3ps65N8xBc \
>     -databaseType MULTIPURPOSE \
>     -templateName New_Database.dbt \
>     -sysPassword *********** \
>     -systemPassword **************** \
>     -storageType ASM \
>     -diskGroupName +DATA \
>     -recoveryGroupName +REDO \
>     -redoLogFileSize 50 \
>     -useOMF true \
>     -totalMemory 4096 \
>     -characterSet AL32UTF8 \
>     -sampleSchema false \
>     -enableArchive true \
>     -initParams sga_target=1536MB,pga_aggregate_target=512MB,nls_language=ENGLISH,nls_territory='AMERICA',db_create_online_log_dest_1='+DATA',processes=300,open_cursors=300 \
>     -automaticMemoryManagement false
Prepare for db operation
5% complete
Registering database with Oracle Restart
7% complete
Creating and starting Oracle instance
9% complete
12% complete
Creating database files
13% complete
17% complete
Creating data dictionary views
19% complete
22% complete

24% complete
26% complete
27% complete
29% complete
32% complete
Oracle JVM
39% complete
46% complete
54% complete
56% complete
Creating cluster database views
57% complete
66% complete
Completing Database Creation
69% complete
70% complete
71% complete
Creating Pluggable Databases
74% complete
85% complete
Executing Post Configuration Actions
100% complete
Database creation complete. For details check the logfiles at:
 /u01/app/oracle/cfgtoollogs/dbca/TESTCDB.
Database Information:
Global Database Name:TESTCDB
System Identifier(SID):TESTCDB
Look at the log file "/u01/app/oracle/cfgtoollogs/dbca/TESTCDB/TESTCDB0.log" for further details.
[oracle@caoradb02 ~]$
[oracle@caoradb02 ~]$

26. Checking DBA_HISTORY & DBA_REGISTRY_SQLPATCH tables

[oracle@caoradb02 ~]$ sqlplus /nolog

SQL*Plus: Release 19.0.0.0.0 - Production on Wed Aug 26 07:00:41 2026
Version 19.32.0.0.0

Copyright (c) 1982, 2026, Oracle.  All rights reserved.

SQL> conn /as sysdba
Connected.
SQL> define
DEFINE _DATE           = "26-AUG-26" (CHAR)
DEFINE _CONNECT_IDENTIFIER = "TESTCDB" (CHAR)
DEFINE _USER           = "SYS" (CHAR)
DEFINE _PRIVILEGE      = "AS SYSDBA" (CHAR)
DEFINE _SQLPLUS_RELEASE = "1932000000" (CHAR)
DEFINE _EDITOR         = "vi" (CHAR)
DEFINE _O_VERSION      = "Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.32.0.0.0" (CHAR)
DEFINE _O_RELEASE      = "1932000000" (CHAR)

SQL> set line 200
column comp_name format a40
col version format a20
column version_full format a20
column status format a20
select comp_name, version, version_full, status, modified from dba_registry;SQL> SQL> SQL> SQL> SQL>

COMP_NAME                                VERSION              VERSION_FULL         STATUS               MODIFIED
---------------------------------------- -------------------- -------------------- -------------------- -----------------------------
Oracle Database Catalog Views            19.0.0.0.0           19.32.0.0.0          VALID                26-AUG-2026 06:48:32
Oracle Database Packages and Types       19.0.0.0.0           19.32.0.0.0          VALID                26-AUG-2026 06:48:32
Oracle Real Application Clusters         19.0.0.0.0           19.32.0.0.0          OPTION OFF           26-AUG-2026 06:37:13
JServer JAVA Virtual Machine             19.0.0.0.0           19.32.0.0.0          VALID                26-AUG-2026 06:48:37
Oracle XDK                               19.0.0.0.0           19.32.0.0.0          VALID                26-AUG-2026 06:48:37
Oracle Database Java Packages            19.0.0.0.0           19.32.0.0.0          VALID                26-AUG-2026 06:48:38
Oracle XML Database                      19.0.0.0.0           19.32.0.0.0          VALID                26-AUG-2026 06:48:33
Oracle Workspace Manager                 19.0.0.0.0           19.32.0.0.0          VALID                26-AUG-2026 06:48:36

8 rows selected.

SQL> set pagesize 10000
set linesize 300
col version format a30
col comments format a70
col ACTION_TIME format a30
select action_time, action, version, comments
from sys.registry$history
order by 1 desc;

ACTION_TIME                    ACTION                         VERSION                        COMMENTS
------------------------------ ------------------------------ ------------------------------ ----------------------------------------------------------------------
                               BOOTSTRAP                      19                             RDBMS_19.32.0.0.0DBRU_LINUX.X64_260705
26-AUG-26 06.43.37.399009 AM   RU_APPLY                       19.0.0.0.0                     Patch applied on 19.32.0.0.0: Release_Update - 260705220710


col version format a20
col ACTION_TIME format a30
col ACTION format a15
col version format a15
col status format a15
col bundle_series format a15
col DESCRIPTION format a40
set lines 200
select install_id,PATCH_UID,PATCH_ID,ACTION,STATUS,ACTION_TIME,DESCRIPTION, source_version, target_version from dba_registry_sqlpatch;

INSTALL_ID  PATCH_UID   PATCH_ID ACTION          STATUS          ACTION_TIME                    DESCRIPTION                              SOURCE_VERSION  TARGET_VERSION
---------- ---------- ---------- --------------- --------------- ------------------------------ ---------------------------------------- --------------- ---------------
         1   28919163   39472050 APPLY           SUCCESS         26-AUG-26 06.43.37.361292 AM   Database Release Update : 19.32.0.0.2607 19.1.0.0.0      19.32.0.0.0
                                                                                                21 (39472050)