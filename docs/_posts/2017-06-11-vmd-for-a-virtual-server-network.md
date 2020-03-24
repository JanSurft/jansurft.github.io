---
layout: post
comments: true
title:  "A virtualized network with OpenBSD's vmm"
project: 
  name: My OpenBSD server
  part: 3
  banner:
    img: my-openbsd-server-project-banner.svg.png
    width: 250px;
    height: 250px;
    thumbnail: my-openbsd-server-project-banner-thumbnail.svg.png
update:
  date: 2017-07-04 18:00:00 +0100
date:   2017-06-12 00:00:00 +0100
categories: openbsd server virtualmachine network
excerpt: I wanted to setup a network of virtual machines on my server. Each VM shall provide its specified service on a dedicated subdomain. I need to create the VMs, establish a virtual connection to my server, handle forwarding of packages with pf and redirecting subdomain requests.
---

**UPDATE:**
As I already suggested in the outlook of my last post, I wanted to exchange `nginx` with `relayd` for redirection. I did this now, thanks to [an answered question on stackoverflow](https://serverfault.com/questions/856807/openbsd-how-to-use-relayd-and-httpd-for-redirecting-subdomain-requests/858849#858849). See the new section: [Configuring relayd on the host-vm]({{page.url}}#configuring-relayd-on-the-host-vm).


Hello dear reader,

in my last post I described the setup of a http server which is reachable through a public domain on OpenBSD. This time I would like to go a little bit further and extend the server with a network of virtual machines, where each machine can be reached by the name of the subdomain it should represent.

Intro
-----

For this setup to work, I needed to download two files from the OpenBSD site:

 - The installation file of the most recent OpenBSD system (at the time it was 6.1)
 - The boot file (bsd.rd)

Afterwards I had to install the VM, configure it, duplicate it for the virtual network.

Then I had to configure the main server and everything worked like a charm in the end.

For better explenation I will include a similar figure as show in my last two posts.

<figure markdown="1">
<figcaption>
<i>Figure 1: Virtual Network on my server</i>
</figcaption>
![Server Infrastructure]({{site.url}}/assets/server-sketch-foo-bar.svg.png 'Figure 1: Virtual Network on my server')
</figure>

You can see that there are serveral components to be configured for the virtual network to work as desired in the end:

I need to...:

- ...configure `pf` for redirection and NAT
- ...configure `unbound` for acting as a DNS server
- ...create three different VMs (host-vm, foo-vm, bar-vm)
- ...connect the VMs to a virtual switch called "localnet"
- ...configure `relayd` on the host-vm for redirection of subdomain requests

### Outline ###

Here a short outline to jump back and forth (turn off `noscript` for a second to see it :-) ):

<div id="toc"></div>

Create the VMs
------------------

This section will deal about creating a raw disk image and installing OpenBSD on it via the OpenBSD included `vmd` framework.
This includes downloading some necessary resources and creating and installing a VM with the application called `vmctl`.

Afterwards the created installation will be duplicated and set up for the different VMs.

### Create the Host VM ###

#### Choose my mirror to download from ####

There are many mirrors that I could choose from: listed [here](https://www.openbsd.org/ftp.html) on the OpenBSD website.

#### Download the files ####

At first I located the necessary files in a webbrowser on my system. I chose the mirror in Frankfurt, so the main url was [https://ftp.hostserver.de/pub/OpenBSD/](https://ftp.hostserver.de/pub/OpenBSD/).

There I chose the most recent OpenBSD version 6.1 and navigated to the directory for amd64 ending here: [https://ftp.hostserver.de/pub/OpenBSD/6.1/amd64/](https://ftp.hostserver.de/pub/OpenBSD/6.1/amd64/).

The necessary files are:

- `install61.fs` the OpenBSD installation image, that I already downloaded when I created a bootable USB Stick for my OpenBSD Installation.
- `bsd.rd` the boot image of OpenBSD.

I opened an ssh-session to the server and downloaded those files via `ftp` (I'm using `ftp` now and not `wget`, as it is in base, thank you for the comment Raf):

```bash
cd ~
mkdir vm-network
cd vm-network
ftp https://ftp.hostserver.de/pub/OpenBSD/6.1/amd64/install61.fs
ftp https://ftp.hostserver.de/pub/OpenBSD/6.1/amd64/bsd.rd
```

As PengouinBSD correctly suggested in the comments, I should also check the downloaded files:

~~~~
cd vm-network
ftp https://ftp.hostserver.de/pub/OpenBSD/6.1/amd64/SHA256.sig
signify -Cp /etc/signify/openbsd-61-base.pub -x SHA256.sig install61.fs bsd.rd
~~~~

From now on I assume you also have a folder called `vm-network` in your user's home directory.

#### Create a raw disk file and start the installation ####

I'm located in my dedicated folder `vm-network`, where the previously downloaded files `install61.fs` and `bsd.rd` are located.

```bash
cd ~/vm-network
```

Within this folder I created a raw disk image called `host.drive` with 8GB:

```bash
doas vmctl create host.drive -s 8G
```

And started installing on this disk interactively with a console:

```bash
doas vmctl start "host-vm" -c -b bsd.rd -m 2G -i 1 -d host.drive -d install61.fs
```
The options that are provided to `vmctl` mean the following:

- `start "host-vm"`: start the virtual machine, naming it "host-vm"
- `-c`: immediately connect the console of the vm into the current shell
- `-b bsd.rd`: choose the specified image as boot kernel
- `-m 2G`: start the virtual machine with two gigabytes of memory
- `-i 1`: create a virtual network interface connected to that virtual machine
- `-d host.drive`: attach the raw disk file where to install OpenBSD on
- `-d install61.fs`: attach the image with the OpenBSD 6.1 installation files

<div class=tip>

+---------------------------------------------------------------------------------------------------------------------------------+
|**A TIP TO PREVENT FUTURE HEADACHES**                                                                                            |
+=================================================================================================================================+
|If you ever run into the problem of this annoying Error when running the command `vmctl start ...`:                              |
|                                                                                                                                 |
|```bash                                                                                                                          |
|doas vmctl start "myvm" -i 1 -d xyz.drive                                                                                        |
|vmctl: start vm command failed: No such file or directory                                                                        |
|```                                                                                                                              |
|                                                                                                                                 |
|then you're probably missing the device file for the taps in `/dev`. The installer creates 4 by default, so you'll have to run...|
|                                                                                                                                 |
|```bash                                                                                                                          |
|cd /dev; sh MAKEDEV tap4                                                                                                         |
|```                                                                                                                              |
|                                                                                                                                 |
|...and so on for each new tap device you need.                                                                                   |
|                                                                                                                                 |
|I took this tip from [here](http://openbsd-archive.7691.n7.nabble.com/vmd-upper-limit-on-number-of-vm-s-td312916.html)           |
|when I ran into a simmilar problem.                                                                                              |
+---------------------------------------------------------------------------------------------------------------------------------+

</div>


#### Guided Installation of OpenBSD for the host-vm ####

In *Table 1* below I show the whole installation process and what I did including some comments.

<figure markdown="1">
<figcaption>
<i>Table 1: Guided Installation</i>
</figcaption>
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
| **Terminal Output**                                                           |            **My Input**      | **Comments**                 |
+===============================================================================+==============================+==============================+
|```    													                    |                              |                              |
|Welcome to the OpenBSD/amd64 6.1 installation program.                         |                              | I want to install OpenBSD    |
|(I)nstall, (U)pgrade, (A)utoinstall or (S)hell?                                |`I`                           |                              |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```    													                    |                              |                              |
|Terminal type? [vt220]                                                         |*return*                      |                              |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |Call it host, because it will |
|System hostname? (short form, e.g. 'foo')                                      |`host`                        |be the host for the vm net.   |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Available network interfaces are: vio0 vlan0                                   |*return*                      |Yes, configure vio0.          |
|Which network interface do you wish to configure? (or 'done') [vio0]           |                              |                              |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|IPv4 address for vio0? (or 'dhcp' or 'none') [dhcp]                            |`192.168.30.2`                |ip address of my vm           |
|```                                                                            |                              |in the virtual network        |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Netmask for vio0? [255.255.255.0]                                              |*return*                      |                              |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|IPv6 address for vio0? (or 'rtsol' or 'none') [none]                           |*return*                      |Don't need an IPv6 address.   |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Which network interface do you wish to configure? (or 'done') [done]           |*return*                      |I'm done.                     |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |The address of the router that|
|Default IPv4 route? (IPv4 address or none)                                     |                              |manages my virtual network.   |
|```                                                                            |`192.168.30.1`                |I chose 192.168.30.1 for the  |
|                                                                               |                              |subnet 192.168.30.0/24.       |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|add net default: gateway 192.168.30.1                                          |                              |                              | 
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |The root domain (In the end it|
|DNS domain name? (e.g. 'bar.com') [my.domain]                                  |`hermes-technology.de`        |will resolve to the hostname  |
|```                                                                            |                              |`host.hermes-technology.de`.  |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |My DNS nameserver should be   |
|DNS nameservers? (IP address list or 'none') [none]                            |`192.168.30.1`                |serving on the virtual NIC    |
|```                                                                            |                              |with that IP.                 |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Password for root account? (will not echo)                                     |2x `mypasswd`                 |I did choose another password |
|Password for root account? (again)                                             |                              |of course.. :D                |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Start sshd(8) by default? [yes]                                                |*return*                      |Yes I want to connect via ssh |
|```                                                                            |                              |later on.                     |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Change the default console to com0? [yes]                                      |*return*                      |sure...                       |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Which speed should com0 use? (or 'done') [9600]                                |*return*                      |definitely...                 |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Setup a user? (enter a lower-case loginname, or 'no') [no]                     |`host`                        |I want the user called "host" |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Full name for user host? [host]                                                |*return*                      |Don't need a full name -.-    |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Password for user host? (will not echo)                                        |2x `mypasswd`                 |Another safe password...      |
|Password for user host? (again)                                                |                              |                              |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|WARNING: root is targeted by password guessing attacks, pubkeys are safer.     |*return*                      |I don't want to support a     |
|Allow root ssh login? (yes, no, prohibit-password) [no]                        |                              |direct root login via ssh.    |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |List me the disks!            |
|Available disks are: sd0 sd1.                                                  |`?`                           |                              |
|Which disk is the root disk? ('?' for details) [sd0]                           |                              |                              |
|```																		    |							   |							  |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |Ok it seems the sd0 with 8G   |
|sd0: Block Device (8.0G)                                                       |                              |is the one I want.            |
|sd1: Block Device (0.3G)                                                       |                              |                              |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```    																		|							   |							  | 
|Available disks are: sd0 sd1.                                                  |*return*                      |Yes, take sd0.                |
|Which disk is the root disk? ('?' for details) [sd0]                           |                              |                              |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|No valid MBR or GPT.                                                           |*return*                      |Use the whole disk!           |
|Use (W)hole disk MBR, whole disk (G)PT or (E)dit? [whole]                      |                              |                              |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Setting OpenBSD MBR partition to whole sd0...done.                             |                              |                              |
|The auto-allocated layout for sd0 is:                                          |                              |                              |
|#                size           offset  fstype [fsize bsize   cpg]             |                              |                              |
|  a:           131.1M               64  4.2BSD   2048 16384     1 # /          |                              |                              |
|  b:           182.1M           268480    swap                                 |                              |                              |
|  c:          8192.0M                0  unused                                 |                              |                              |
|  d:           201.7M           641504  4.2BSD   2048 16384     1 # /tmp       |                              |                              |
|  e:           212.8M          1054560  4.2BSD   2048 16384     1 # /var       |*return*                      |Auto layout worked for me..   |
|  f:           951.1M          1490304  4.2BSD   2048 16384     1 # /usr       |                              |                              |
|  g:           542.6M          3438080  4.2BSD   2048 16384     1 # /usr/X11R6 |                              |                              |
|  h:          2150.1M          4549376  4.2BSD   2048 16384     1 # /usr/local |                              |                              |
|  i:          1044.4M          8952832  4.2BSD   2048 16384     1 # /usr/src   |                              |                              |
|  j:          1340.8M         11091808  4.2BSD   2048 16384     1 # /usr/obj   |                              |                              |
|  k:          1432.5M         13837856  4.2BSD   2048 16384     1 # /home      |                              |                              |
|Use (A)uto layout, (E)dit auto layout, or create (C)ustom layout? [a]          |                              |                              |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Rounding size to bsize (32 sectors): 268416                                    |                              |                              |
|Rounding offset to bsize (32 sectors): 641504                                  |                              |                              |
|Rounding size to bsize (32 sectors): 413056                                    |                              |                              |
|Rounding size to bsize (32 sectors): 435744                                    |                              |                              |
|Rounding size to bsize (32 sectors): 1947776                                   |                              |                              |
|Rounding size to bsize (32 sectors): 1111296                                   |                              |                              |
|Rounding size to bsize (32 sectors): 4403456                                   |                              |                              |
|Rounding size to bsize (32 sectors): 2138976                                   |                              |                              |
|Rounding size to bsize (32 sectors): 2746048                                   |                              |                              |
|Rounding size to bsize (32 sectors): 2933856                                   |                              |                              |
|/dev/rsd0a: 131.1MB in 268416 sectors of 512 bytes                             |                              |                              |
|4 cylinder groups of 32.77MB, 2097 blocks, 4224 inodes each                    |                              |                              |
|/dev/rsd0k: 1432.5MB in 2933856 sectors of 512 bytes                           |                              |                              |
|8 cylinder groups of 202.47MB, 12958 blocks, 25984 inodes each                 |                              |                              |
|/dev/rsd0d: 201.7MB in 413056 sectors of 512 bytes                             |                              |                              |
|4 cylinder groups of 50.42MB, 3227 blocks, 6528 inodes each                    |*return*                      |Don't need another disk.      |
|/dev/rsd0f: 951.1MB in 1947776 sectors of 512 bytes                            |                              |                              |
|5 cylinder groups of 202.47MB, 12958 blocks, 25984 inodes each                 |                              |                              |
|/dev/rsd0g: 542.6MB in 1111296 sectors of 512 bytes                            |                              |                              |
|4 cylinder groups of 135.66MB, 8682 blocks, 17408 inodes each                  |                              |                              |
|/dev/rsd0h: 2150.1MB in 4403456 sectors of 512 bytes                           |                              |                              |
|11 cylinder groups of 202.47MB, 12958 blocks, 25984 inodes each                |                              |                              |
|/dev/rsd0j: 1340.8MB in 2746048 sectors of 512 bytes                           |                              |                              |
|7 cylinder groups of 202.47MB, 12958 blocks, 25984 inodes each                 |                              |                              |
|/dev/rsd0i: 1044.4MB in 2138976 sectors of 512 bytes                           |                              |                              |
|6 cylinder groups of 202.47MB, 12958 blocks, 25984 inodes each                 |                              |                              |
|newfs: reduced number of fragments per cylinder group from 27232 to 27120      |                              |                              |
|to enlarge last cylinder group                                                 |                              |                              |
|/dev/rsd0e: 212.8MB in 435744 sectors of 512 bytes                             |                              |                              |
|5 cylinder groups of 52.97MB, 3390 blocks, 6784 inodes each                    |                              |                              |
|Available disks are: sd1.                                                      |                              |                              |
|Which disk do you wish to initialize? (or 'done') [done]                       |                              |                              |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Let's install the sets!                                                        |`disk`                        |Ok the sets are on the disk   |
|Location of sets? (disk http or 'done') [http]                                 |                              |with "install61.fs" on.       |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Is the disk partition already mounted? [no]                                    |*return*                      |No the other disk is not      |
|```                                                                            |                              |mounted yet.                  |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Available disks are: sd0 sd1.                                                  |*return*                      |Ok sd0 was the 8G so sd1      |
|Which disk contains the install media? (or 'done') [sd1]                       |                              |should be the one I want.     |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Which disk contains the install media? (or 'done') [sd1]                       |                              |                              |
|  a:           572416             1024  4.2BSD   2048 16384 16142              |                              |mmh, yes seems as if partition|
|  i:              960               64   MSDOS                                 |*return*                      |`a` contains the sets.        |
|Available sd1 partitions are: a i.                                             |                              |                              |
|Which sd1 partition has the install sets? (or 'done') [a]                      |                              |                              |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Pathname to the sets? (or 'done') [6.1/amd64]                                  |*return*                      |That pathname sounds good to  |
|```                                                                            |                              |me                            |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Select sets by entering a set name, a file name pattern or 'all'. De-select    |                              |                              |
|sets by prepending a '-' to the set name, file name pattern or 'all'. Selected |                              |I want them all!!             |
|sets are labelled '[X]'.                                                       |                              |                              |
|    [X] bsd           [X] base61.tgz    [X] game61.tgz    [X] xfont61.tgz      |`all`                         |                              |
|    [X] bsd.rd        [X] comp61.tgz    [X] xbase61.tgz   [X] xserv61.tgz      |                              |                              |
|    [ ] bsd.mp        [X] man61.tgz     [X] xshare61.tgz                       |                              |                              |
|Set name(s)? (or 'abort' or 'done') [done]                                     |                              |                              |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|    [X] bsd           [X] base61.tgz    [X] game61.tgz    [X] xfont61.tgz      |                              |                              |
|    [X] bsd.rd        [X] comp61.tgz    [X] xbase61.tgz   [X] xserv61.tgz      |*return*                      |Ok, now you can go on.        |
|    [X] bsd.mp        [X] man61.tgz     [X] xshare61.tgz                       |                              |                              |
|Set name(s)? (or 'abort' or 'done') [done]                                     |                              |                              |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |There is no way around that.. |
|Directory does not contain SHA256.sig. Continue without verification? [no]     |`yes`                         |                              |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Installing bsd          100% |**************************| 10433 KB    00:00    |                              |                              |
|Installing bsd.rd       100% |**************************|  9210 KB    00:00    |                              |                              |
|Installing bsd.mp       100% |**************************| 10499 KB    00:00    |                              |                              |
|Installing base61.tgz   100% |**************************| 52322 KB    00:04    |                              |                              |
|Extracting etc.tgz      100% |**************************|   189 KB    00:00    |                              |                              |
|Installing comp61.tgz   100% |**************************| 46070 KB    00:04    |                              |                              |
|Installing man61.tgz    100% |**************************|  8719 KB    00:00    |*return*                      |                              |
|Installing game61.tgz   100% |**************************|  2707 KB    00:00    |                              |That's it with the sets.      |
|Installing xbase61.tgz  100% |**************************| 17497 KB    00:01    |                              |                              |
|Extracting xetc.tgz     100% |**************************|  7006       00:00    |                              |                              |
|Installing xshare61.tgz 100% |**************************|  4406 KB    00:00    |                              |                              |
|Installing xfont61.tgz  100% |**************************| 39342 KB    00:02    |                              |                              |
|Installing xserv61.tgz  100% |**************************| 13001 KB    00:00    |                              |                              |
|Location of sets? (disk http or 'done') [done]                                 |                              |                              |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|What timezone are you in? ('?' for list) [Canada/Mountain]                     |                              |                              |
|Africa/      Chile/       GB-Eire      Israel       Navajo       US/           |                              |                              |
|America/     Cuba         GMT          Jamaica      PRC          UTC           |                              |                              |
|Antarctica/  EET          GMT+0        Japan        PST8PDT      Universal     |                              |                              |
|Arctic/      EST          GMT-0        Kwajalein    Pacific/     W-SU          |                              |                              |
|Asia/        EST5EDT      GMT0         Libya        Poland       WET           |`?`                           |Aha... ok I guess there is    |
|Atlantic/    Egypt        Greenwich    MET          Portugal     Zulu          |                              |a Berlin in Europe...         |
|Australia/   Eire         HST          MST          ROC          posix/        |                              |                              |
|Brazil/      Etc/         Hongkong     MST7MDT      ROK          posixrules    |                              |                              |
|CET          Europe/      Iceland      Mexico/      Singapore    right/        |                              |                              |
|CST6CDT      Factory      Indian/      NZ           Turkey                     |                              |                              |
|Canada/      GB           Iran         NZ-CHAT      UCT                        |                              |                              |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|What timezone are you in? ('?' for list) [Canada/Mountain]                     |`Europe/Berlin`               |...so I take that.            |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|Saving configuration files...done.                                             |                              |                              |
|Making all device nodes...done.                                                |                              |                              |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+
|```                                                                            |                              |                              |
|CONGRATULATIONS! Your OpenBSD install has been successfully completed!         |                              |                              |
|To boot the new system, enter 'reboot' at the command prompt.                  |                              |Made it!                      |
|When you login to your new system the first time, please read your mail        |                              |                              |
|using the 'mail' command.                                                      |                              |                              |
|```                                                                            |                              |                              |
+-------------------------------------------------------------------------------+------------------------------+------------------------------+

</figure>

Ok now he is telling me to reboot the machine... But I can easily just choose to exit the vm via this key-sequence:

```bash
~^D
```

So first enter the **tilde** symbol and afterwards **Ctrl-D**.

*The tilde is not supposed to apear in the terminal input.*

Thereafter I stopped the created virtual machine:

```bash
doas vmctl stop "host-vm"
```

And made a copy of the installation:

```bash
doas cp host.drive host.drive.bak
```

I also checked if everything installed fine:

```
doas vmctl start "host-vm" -c -i 1 -d host.drive
```

It should boot into the installed system now asking you for login and password in the end.

I configured `doas` and added the `/etc/installurl` file as shown in my last [post]({{page.previous.url}}#openbsd-server---install-and-set-up).



### Duplicate the Host VM for other VMs I want ###

Now I could easily duplicate the created disk file for other needed VMs:

```bash
doas cp host.drive foo.drive
doas cp host.drive bar.drive
```

Afterwards I started each VM and did some adjustments (I will only show what I did for the "foo" vm as the "bar" vm will be configured analogously:

Starting the VM as usual:

```bash
doas vmctl start "foo-vm" -c -i 1 -d foo.drive
```

Add the foo user:

```bash
doas adduser
```

I copied my terminal output:

```
Couldn't find /etc/adduser.conf: creating a new adduser configuration file
Reading /etc/shells
Enter your default shell: csh ksh nologin sh [ksh]: 
Your default shell is: ksh -> /bin/ksh
Default login class: authpf bgpd daemon default pbuild staff unbound 
[default]: 
Enter your default HOME partition: [/home]: 
Copy dotfiles from: /etc/skel no [/etc/skel]: 
Send welcome message?: /path/file default no [no]: 
Do not send message(s)
Prompt for passwords by default (y/n) [y]: 
Default encryption method for passwords: auto blowfish [auto]: 
Use option ``-silent'' if you don't want to see all warnings and questions.

Reading /etc/shells
Check /etc/master.passwd
Check /etc/group

Ok, let's go.
Don't worry about mistakes. There will be a chance later to correct any input.
Enter username []: foo
Enter full name []: 
Enter shell csh ksh nologin sh [ksh]: 
Uid [1001]: 
Login group foo [foo]: 
Login group is ``foo''. Invite foo into other groups: guest no 
[no]: wheel
Login class authpf bgpd daemon default pbuild staff unbound 
[default]: 
Enter password []: 
Enter password again []: 

Name:        foo
Password:    ******
Fullname:    foo
Uid:         1001
Gid:         1001 (foo)
Groups:      foo wheel
Login Class: default
HOME:        /home/foo
Shell:       /bin/ksh
OK? (y/n) [y]: 
Added user ``foo''
Copy files from /etc/skel to /home/foo
Add another user? (y/n) [y]: n
Goodbye!
```

Deleted the host user:

```bash
doas userdel host
doas rm -rf /home/host
```

Configured the new hostname:

```bash
## /etc/hosts
127.0.0.1       localhost
::1             localhost
192.168.30.10   foo.hermes-technology.de foo
```

```bash
## /etc/myname
foo.hermes-technology.de
```

Alter the `/etc/hostname.vio0` for the correct ip (it will be 192.168.30.4 for the bar-vm):

```bash
## /etc/hostname.vio0
inet 192.168.30.3 255.255.255.0
```

Then I enabled httpd to show a "Hello from foo" html page.

Refer to my last post to see how to [setup httpd for this task]({{page.previous.url}}#start-httpd-and-show-your-website):

I exited the VM.

**I did the above for each VM that I added to the virtual network.**



Back on the main server
-----------------------

Ok now that I had the `host-vm`, `foo-vm` and `bar-vm` successfully set up I had to do some configuration on the main server.

At first I created a virtual NIC that acts as a Router and DNS server to the virtual-machine-network.

Then I configured the internal firewall `pf` and the DNS service via `unbound`.

At the end I configured the virtual machines for `vmd` in `/etc/vm.conf`.

### The virtual network interface card (NIC) ###

Creating a virtual network device was very easy in OpenBSD.

I just had to create a file called `/etc/hostname.vether0` and insert the desired configuration:

```bash
doas -s
touch /etc/hostname.vether0
echo "inet 192.168.30.1 255.255.255.0 NONE" > /etc/hostname.vether0
```

Now on next reboot or after restarting the networking service I had the vether0 device at 192.168.30.1.

### PF - the OpenBSD firewall ###

There is a configuration file for the firewall at `/etc/pf.conf`, I configured it like this:

```bash
#       $OpenBSD: pf.conf,v 1.54 2014/08/23 05:49:42 deraadt Exp $
#
# See pf.conf(5) and /etc/examples/pf.conf

int_if="{ vether0 em0 }"

##set skip on lo

##block return  # block stateless traffic
##pass          # establish keep-state

# By default, do not permit remote connections to X11
##block return in on ! lo0 proto tcp to port 6000:6010

set block-policy drop
set loginterface egress
set skip on lo0

## act as a nat
match in all scrub (no-df random-id max-mss 1440)
match out on egress inet from !(egress:network) to any nat-to (egress:0)

## allow all outgoing
pass out quick inet
pass in on $int_if inet

## redirect http and https to the host of the vms
pass in on egress inet proto tcp from any to (egress) port { 80 443 } rdr-to 192.168.30.2
```

Now incoming http traffic will be redirected to the host-vm as soon as it is up and running.

To apply the configuration changes I executed `doas pfctl -f /etc/pf.conf`.

And verified those changes via `doas pfctl -sr`.



### unbound - my DNS name server ###

I enabled `unbound`:

```bash
doas rcctl enable unbound
```

And configured it the way I needed it:

```bash
## /var/unbound/etc/unbound.conf                                                                                                                                                                       
# $OpenBSD: unbound.conf,v 1.7 2016/03/30 01:41:25 sthen Exp $

## I definately want the vether0 device act as a DNS name server for the virtual network
server:
        interface: 192.168.30.1
        interface: 127.0.0.1
        interface: ::1
        #do-ip6: no

        # override the default "any" address to send queries; if multiple
        # addresses are available, they are used randomly to counter spoofing
        #outgoing-interface: 192.0.2.1
        #outgoing-interface: 2001:db8::53

        access-control: 0.0.0.0/0 refuse
        access-control: 127.0.0.0/8 allow
        access-control: ::0/0 refuse
        access-control: ::1 allow
        access-control: 192.168.1.0/24 allow

        access-control: 192.168.30.0/24 allow ## I want the virtual network to be allowed for access
        
        do-not-query-localhost: no

        hide-identity: yes
        hide-version: yes

        # Uncomment to enable qname minimisation.
        # https://tools.ietf.org/html/draft-ietf-dnsop-qname-minimisation-08
        #
        # qname-minimisation: yes

        # Uncomment to enable DNSSEC validation.
        #
        #auto-trust-anchor-file: "/var/unbound/db/root.key"

        # Serve zones authoritatively from Unbound to resolver clients.
        # Not for external service.
        #
        #local-zone: "local." static
        #local-data: "mycomputer.local. IN A 192.0.2.51"
        #local-zone: "2.0.192.in-addr.arpa." static
        #local-data-ptr: "192.0.2.51 mycomputer.local"

        # UDP EDNS reassembly buffer advertised to peers. Default 4096.
        # May need lowering on broken networks with fragmentation/MTU issues,
        # particularly if validating DNSSEC.
        #
        #edns-buffer-size: 1480

        # Use TCP for "forward-zone" requests. Useful if you are making
        # DNS requests over an SSH port forwarding.
        #
        #tcp-upstream: yes

        # DNS64 options, synthesizes AAAA records for hosts that don't have
        # them. For use with NAT64 (PF "af-to").
        #
        #module-config: "dns64 validator iterator"
        #dns64-prefix: 64:ff9b::/96     # well-known prefix (default)
        #dns64-synthall: no

remote-control:
        control-enable: yes
        control-use-cert: no
        control-interface: /var/run/unbound.sock

forward-zone:
        name: "."
        forward-addr: 192.168.1.1 ## Forward the DNS Requests to my local real router
        forward-addr: 74.82.42.42 # he.net
        forward-addr: 2001:470:20::2 # he.net v6
        forward-addr: 8.8.8.8 # google.com
        forward-addr: 2001:4860:4860::8888 # google.com v6
        forward-addr: 208.67.222.222 # opendns.com
        forward-first: yes # try direct if forwarder fails
```

Now DNS requests from the 192.168.30.0/24 subnet will be answered by the DNS server at 192.168.30.1.


### vmd - What goes into /etc/vm.conf

Now my next task was to create the correct vm configuration, so that each vm would be connected to a local virtual switch managing the virtual network.

~~~~ {.bash .numberLines startFrom="1"}
## /etc/vm.conf
files=  /home/user/vm-network/ # our disk files are at the previously created location (change "user" to your username)

vm host-vm { # we want a vm called "host-vm"
        memory 2g #with 2gigs of memory
        disk $files host.drive # running the host.drive
        interface tap { lladdr 00:00:00:00:00:02 switch localnet } # on a network interface with the specified MAC on the localnet switch
}

vm foo-vm {
        memory 2g
        disk $files foo.drive
        interface tap { lladdr 00:00:00:00:00:03 switch localnet }
}

vm bar-vm {
        memory 2g
        disk $files bar.drive
        interface tap { lladdr 00:00:00:00:00:04 switch localnet }
}

switch localnet { # this is the switch called "localnet"
        add vether0 # where the virtual interface is added to
}
~~~~


So on lines 4, 10 and 16 I configured the specific VMs and on line 22 I configured the virtual switch that the VMs network interfaces are attached to.

Then I enabled `vmd`:

```bash
doas rcctl enable vmd
```

And restarted the server:

```bash
doas reboot
```

### Configuring relayd on the host-vm ###

The last task was the configuration of `relayd` on the host-vm.

For this I logged into the host-vm, which should have been started automatically now at reboot:

```bash
doas vmctl console host-vm
```

Then I configured relayd to redirect requests to my subdomains:

~~~~ {.ini}
# /etc/relayd.conf                                                                                       

## MACROS

host_vm=192.168.30.2
foo_vm=192.168.30.3
bar_vm=192.168.30.4

## TABLES

table <foo_service> { $foo_vm }
table <bar_service> { $bar_vm }

## PROTOCOLS

# define a new http protocol called "reverseproxy"
http protocol "reverseproxy" {
        
		# match a request that has a Host value with "foo.hermes-technology.de"
		# and forward that to the foo_service
		# "quick" means that it will be handled as the last rule if it matches... no other will be processed
        match request quick header "Host" value "foo.hermes-technology.de" \
                forward to <foo_service>

		match request quick header "Host" value "www.hermes-technology.de" \
				forward to <foo_service>
        
        match request quick header "Host" value "bar.hermes-technology.de" \
                forward to <bar_service>
}

## RELAYS

# create a new relay called "proxy"
# relays are for layer 7 (e.g. http)
relay "proxy" {
		# the relay should listen on the host ip on port 80
        listen on $host_vm port 80
        
		# use the protocol "reverseproxy" we defined above
        protocol "reverseproxy"
        
		# forwarding is enabled for the specified services
        forward to <foo_service> port 80
        forward to <bar_service> port 80
}
~~~~

The last task was to enable and start `relayd`:

~~~~ {.bash}
doas rcctl enable relayd
doas rcctl start relayd
~~~~

This does work now
--------------------

Because I bought the domain hermes-technology.de and registered blog.hermes-technology.de as CNAME entries, the following does work:

1. Enter blog.hermes-technology.de anywhere into a webbrowser.
2. The request lands at my main server's ip (hermes-technology.de).
3. PF redirects any http requests to the host-vm on 192.168.30.2.
4. `relayd` on the host-vm redirects the "blog" subdomain request to the ip 192.168.30.3 of the blog-vm.
5. The blog-vm and its httpd-service sends the response to its gateway 192.168.30.1
6. The response on the vether0 gets a Network Address Translation (NAT) by `pf` to the router.
7. The router sends the response to the client.

Outlook
-------

In the next post I will explain how I set up a proper ssh connection to my server with a public key. Which is much safer than using a password. Also I will explain how to configure ssh-tunneling so that you login to your virtual servers from the workstation where you're maintaining your server from. At last I will explain how I configured `pf` to do an ssh protection like `fail2ban` does.
