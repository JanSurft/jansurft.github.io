---
layout: post
title: Making ssh more secure (UPDATE!)
update:
  date: 2017-07-04 18:00:00 +0100
project:
  name: My OpenBSD server
  part: 4
  banner:
    img: my-openbsd-server-project-banner.svg.png
    width: 250px;
    height: 250px;
    thumbnail: my-openbsd-server-project-banner-thumbnail.svg.png
excerpt: I wanted my server's ssh access to be much more secure than default. This includes choosing strong algorithms for authentication, integrity and encription as well as setting up a two-factor login via Google Authenticator.
---

UPDATE:
I upgraded the whole ssh setup on client and server to be much more secure, thanks to PengouinBSD's comment!

Hello again,

as I wrote in my [last post]({{page.previous.url}}#outlook) I want to take care a bit about ssh connection and its security. So today's task will be:

- Create an ssh-key on my workstation and add the public key to the server's authorized keys
- Configure the ssh daemon (sshd) on the server (no root permit, no password permit, only public key)
- Do the same for each virtual machine
- Enable a `fail2ban` like functionality via `pf`, banning specific IP addresses that tried to connect too often or too fast

A short outline for jumping around:

<div id="toc"></div>

Intro
-----

Establishing an ssh connection to the server is great if you want to remotely sanitize the system and do some maintenance work on the server. But of course by opening a new way to access the server for yourself you are also opening a new way for potential attacks on your server.

<!--Upon roaming through the net and looking for information I often stumbled across the people saying "most secure way is to disallow ssh from the internet as a total" and while that's true-->

But as usual there are ways to make this connection more secure than default.

My Scenario
-----------

I had a server setup operating openssh on OpenBSD 6.1 that was disallowing root login totally and only allowing users to login ssh via their passwords. SSH service is running on port 22. This configuration is the default if you enabled ssh and chose not to permit root login for ssh during the installation process of OpenBSD. As I did for example do in [this installation guide]({{page.previous.url}}#guided-installation-of-openbsd-for-the-host-vm).

I want to change that into only allowing the user to login with public keys and the Google Authenticator App as a second factor.

SSH - Public key authentication for the server and each VM
----------------------------------------------------------

In this section I will write how I set up the ssh public key connection for my workstations and the server with the VMs running on it. This will include some paranoid precaution, the creation of the keys, the transferral of the public keys to the servers (main server and VMs) and setting up the ssh config on the workstation for establishing easy connections.

This section will be completely updated as for the comment of PengouinBSD. As I read by his resources, the public key setup that I chose was not really secure (at least it can be much more secure). At first I want to share those resources that PengouinBSD shared at the top of this new section:

[Key derivation: Improving the security of your SSH private key files by Martin Kleppman](https://martin.kleppmann.com/2013/05/24/improving-security-of-ssh-private-keys.html)

[Key derivation: new openssh key format and bcrypt pbkdf by Ted Unangst](http://www.tedunangst.com/flak/post/new-openssh-key-format-and-bcrypt-pbkdf)

[Client/Server authentication: Secure Secure Shell by stribika](https://stribika.github.io/2015/01/04/secure-secure-shell.html)

The resource by Martin Kleppmann is showing how you can implement a key derivation for ssh private keys. In the header of his post he is pointing out that his article is not relevant for newer versions of OpenSSH anymore as those are supporting the `-o` Option mentioned by PengouinBSD which integrates a new stronger format with key derivation.

The second resource by Ted Unangst is about a new OpenSSH key format. The keyformat is using stronger key derivation functions which are enabled by default for keys using ed25519 signatures. Also he mentions how to upgrade the old keyformat to the new one. 

In the last resource stribika provides a profound explanation on how to setup your server/client key authentication. I will mainly follow his setup and make my access security much better.

### Taking precaution ###

For setting up all the ssh configurations I disconnected my server and my workstation from the internet (not from the LAN) so there could not be any interceptions to the internal traffic when I setup the public key authentication.

### Create an ssh-key ###

On the workstation I wanted to be able to reach my server from, I created an ssh-key:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -o -a 64
```

### Copy the key to the server ###

Copying the key to the server for public key authentication of ssh sessions is easy.

Whenever I have the chance to use `ssh-copy-id`, I use [that method]({{page.url}}#with-ssh-copy-id). In other cases I do a variation of the [second method]({{page.url}}#without-ssh-copy-id).

#### With ssh-copy-id ####

After generating the key I needed to transfer it to my server.

There are several ways to do this. The first thing to try out is using `ssh-copy-id` like so (the server's IP is at 192.168.1.250 with the user `jan-server`):

```bash
ssh-copy-id -i ~/.ssh/id_ed25519 -p 22 jan-server@192.168.1.250
```

#### Without ssh-copy-id ####

There were cases when I couldn't use `ssh-copy-id`, what I usually did then was:

- Opening an ssh session in a terminal to the ssh public key receiver via `ssh -p 22 myuser@192.168.1.250`
- Open another terminal and copy the content of the public key file to the clipboard (**Do not** use the file `~/.ssh/id_ed25519` that is the private key file which should never leave your workstation but the file `~/.ssh/id_ed25519.pub` the public key file belonging to that key)

```bash
cat ~/.ssh/id_ed25519.pub | xclip -selection clipboard
```

This last command needs `xclip` on your workstation (on a Debian like system install it via `sudo apt install xclip`).

Append the clipboard content to the authorized-keys file like so (pasting in the terminal `Ctrl-Shift-V` or with an editor of your choice like vim):

```bash
echo "ssh-ed25519 AAF23409SLFKJE02394FFTtlksdfowie3422DKdcweoDweoDFJwode99973fdOdjf9WT jan@jans-workstation" >> ~/.ssh/authorized_keys
```

### Changing ssh configuration on client and server ###

There are a lot of things to consider when changing the clients' and servers' configuration for OpenSSH.

For most of the configurations (nearly all), I followed [the documentation by stribika](https://stribika.github.io/2015/01/04/secure-secure-shell.html). Thank you for this great setup!

Additionally I also set up a two factor authentication with the Google Authenticator App on my android device.

### Setting up (client and server) ###


Stribika proposed to change or generate the `/etc/ssh/moduli` file. Because mine already existed, I modified my `/etc/ssh/moduli` file like so ([explained here](https://stribika.github.io/2015/01/04/secure-secure-shell.html)):

~~~~  {.bash .numberLines startFrom="1"}
awk '$5 > 2000' /etc/ssh/moduli > "${HOME}/moduli"
wc -l "${HOME}/moduli" # make sure there is something left
sudo cp /etc/ssh/moduli /etc/ssh/moduli.bak
sudo mv "${HOME}/moduli" /etc/ssh/moduli
~~~~

- *Line 1*: Get all lines from `/etc/ssh/moduli` that have a fifth column of a value greater than 2000 and copy them into a file in `~/moduli`.
- *Line 2*: Make sure that there are still lines left in the generated file.
- *Line 3*: Make a backup of `moduli` in case something goes wrong in the future.
- *Line 4*: Copy the generated file over the existing one.

### SSH configuration (server) ###


#### The sshd_config ####

To alter the configuration of my ssh daemon on the server, I had to manipulate the file `/etc/ssh/sshd_config` as shown below.

The code snippet below shows the configuration that I definitely set for my sshd service (comments point out the different functionalities):

~~~~ {.ini .numberLines startFrom="1"}
# /etc/ssh/sshd_config

# Make sure that ssh protocol version 2 is used only!
Protocol 2

# Set the hostkeys that will be used for server authentication at the client
# first preferred one:
HostKey /etc/ssh/ssh_host_ed25519_key
# fallback:
HostKey /etc/ssh/ssh_host_rsa_key

# Chose a port that is not "standard" so default port scanning on low ports fail
# The port number can be a 16bit Integer. So the maximum is 65535
Port 13423

# Tell sshd which key exchange algorithms it is allowed to use. The resource by stribka at
# https://stribika.github.io/2015/01/04/secure-secure-shell.html is explaining why these two (curve25519 and diffie-hellman sha256)
# are the only chosen ones
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256

# Only allow strong symmetric cyphers (see stribka's resource for detailed information)
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

# Only allow strong hmacs for message integrity (see stribka's resource for detailed information)
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-ripemd160-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,hmac-ripemd160,umac-128@openssh.com

# I do not want to permit root login for ssh in general
# If I would like to do that later I would choose to do it in a Match rule for specific addresses for example
PermitRootLogin no

# The default is to check both .ssh/authorized_keys and .ssh/authorized_keys2
# but this is overridden so installations will only check .ssh/authorized_keys
AuthorizedKeysFile      .ssh/authorized_keys

# Generally I want to disalow any kind of access
# and handle it in user or address specific match rules
# so disable pubkey authentication at first
PubkeyAuthentication no

# To disable tunneled clear text passwords:
PasswordAuthentication no

# allow challenge reponse authentication for 2 factor authentication with google authenticator
ChallengeResponseAuthentication yes

# We do not want to permit empty passwords in any case:
PermitEmptyPasswords no

# Generally disallow tcp forwarding
AllowTcpForwarding no

# override default of no subsystems
Subsystem       sftp    /usr/libexec/sftp-server

# only allow ssh sessions for members of the ssh-user group
AllowGroups ssh-user

# then when its a member of the group ssh-user (like my user jan-server will be) to be logged in, do some specific actions:
Match Group ssh-user 
		
		# Allow tcp forwarding for the user jan-server (for enabling ssh session forwarding to my virtual machines)
		AllowTcpForwarding yes
		
		# Allow password authentication (for allowing google authenticator OTP's) 
		PasswordAuthentication yes
		
		# And allow pubkey authentication, so my generated pubkey can be used
        PubkeyAuthentication yes

		# Prompt for authentication in the following order: first ask for authenticaton of the public key then prompt for the two factor key on google-authenticator
		AuthenticationMethods publickey,password

~~~~

#### New user groups and keyfiles ####

After changing the configuration file I created a group called `ssh-user` on the server:

~~~~ {.bash}
doas groupadd ssh-user
~~~~

and added my local user `jan-server` to that group:

~~~~ {.bash}
doas user mod -G ssh-user jan-server
~~~~

Then I deleted all host key files on the server and generated new ones:

~~~~ {.bash}
cd /etc/ssh

# delete the host key files existing:
rm ssh_host_*key*

# generate new ones that we use (only those two mentioned in the sshd_config)
ssh-keygen -t ed25519 -f ssh_host_ed25519_key -N "" < /dev/null
ssh-keygen -t rsa -b 4096 -f ssh_host_rsa_key -N "" < /dev/null
~~~~

#### Google authenticator integration ####

As an additional instance of security I wanted to integrate Google Authenticator as a second factor. I chose that because I already had it installed on my Android device. It is also [open source](https://github.com/google/google-authenticator).

Google Authenticator supports the [HMAC-based One-time Password Algorithm](https://de.wikipedia.org/wiki/HMAC-based_One-time_Password_Algorithmus) (OATH-HOTP) as of [RFC 4226](https://tools.ietf.org/html/rfc4226).

##### Pre-Requisites #####

I installed the following packages:

~~~~ {.bash}
doas pkg_add login_oath
doas pkg_add node
~~~~

- `login_oath` is used for using the time based one time password compatible to the google authenticator.

- `node` is used for installing a convenient wrapper for setting up the key-file for the one-time-password service.

Afterwards I installed a tool for creating the keyfile for the Google Authenticator, I read the sourcecode beforehand to be sure its safe.:

~~~~ {.bash}
npm install  -g https://github.com/WIZARDISHUNGRY/totp-util
~~~~

##### Set up the key file and give it to my Android device #####

On the server I then set up the keyfile by running `totp-util` as the user I would like to be able to log in with (in my case that user was `jan-server`).

~~~~ {.bash}
totp-util
~~~~

I scanned the QR-code appearing on the console with my google authenticator app on my android phone.

##### Configure login.conf for the OTP integration #####

I added a new login class to `/etc/login.conf` at the end of the file (appending) like so:

~~~~ {.bash .numberLines startFrom="1"}
totppw:\
	:auth-ssh=-totp,skey:\
	:tc=default:
~~~~ 
  
- *Line 1*: the name of the new login class.
- *Line 2*: specifying the allowed login methods for ssh authentication to -totp (timebased one-time-password) and skey.
- *Line 3*: use the defaults for everything else.

I then recompiled the `login.conf` file:

~~~~ {.bash}
doas cap_mkd /etc/login.conf
~~~~

And changed my user's login class to the newly generated `totppw`:

~~~~ {.bash}
doas usermod -L totppw jan-server
~~~~

#### At the end of the server configuration ####

I needed to reload the configuration file for the service:

```bash
doas rcctl reload sshd
```

### SSH configuration (client) ###

The configuration for the client is done in `/etc/ssh/ssh_config` and corresponds with the configurations that I chose for the server:

~~~~
Host *
    PasswordAuthentication yes
	
	ChallengeResponseAuthentication yes

    PubkeyAuthentication yes

	# this will choose the following algorithms for hostkey, ciphers and hmacs in the order from left to right (see Stribika's documentation for more info):
    HostKeyAlgorithms ssh-ed25519-cert-v01@openssh.com,ssh-rsa-cert-v01@openssh.com,ssh-ed25519,ssh-rsa

	Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
	
	MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-ripemd160-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,hmac-ripemd160,umac-128@openssh.com
~~~~

### That's what I can do now ###

Now when I do `ssh -p 13423 -i ~/.ssh/id_ed25519 jan-server@192.168.1.250`, I am able to connect to my server via public key authentication and google authenticator like so (password are of course not shown in terminal input but I included them for better presentation):

~~~~ {.bash}
ssh -p 13423 -i ~/.ssh/id_ed25519 jan-server@192.168.1.250
Enter passphrase for key '.ssh/id_ed25519': mypubkeypasswd
Authenticated with partial success.
user@192.168.1.13's password: 123456
~~~~

For my convenience I also added these lines into my workstation's `~/.ssh/config` file:

```bash
# ~/.ssh/config

Host server-local
	Port 13423
	HostName 192.168.1.250
	User jan-server
	IdentityFile ~/.ssh/id_ed25519

Host server-remote
	Port 13423
	HostName hermes-technology.de
	User jan-server
	IdentityFile ~/.ssh/id_ed25519
```

Now I can just do `ssh server-local` when I want to connect to my server from the local network or `ssh server-remote` when I want to connect from a remote place.

### Configure the ssh daemon (sshd) on the virtual machines ###

As you may have noticed from my last posts: I have a server infrastructure, where different subdomain requests are forwarded to virtual machines on the main server.

So for being able to do the same convenient ssh maintenance on my virtual machines, without ssh'ing to my main server and then connecting to the VMs via `vmctl` [as explained here]({{page.previous.url}}#installing-and-configuring-nginx-on-the-host-vm), I have to configure the ssh daemons on the virtual machines as well and enable the public key authentication.

I will explain how I did it on the `host-vm`.

Because OpenBSD on the `host-vm`  was installed as explained in the [installation guide in my last post]({{page.previous.url}}#guided-installation-of-openbsd-for-the-host-vm), the ssh daemon is enabled by default and root login is prohibited.

On my workstation I logged in via ssh into my main server:

```bash
ssh server-local
```

Then I logged into the `foo-vm`:

```bash
vmctl console host-vm
```

To copy the ssh public key [that I generated on my workstation]({{page.url}}#create-an-ssh-key), I chose the manual method without `ssh-copy-id` as explained [here]({{page.url}}#without-ssh-copy-id).

Thereafter I first configured the `/etc/ssh/moduli` file as explained [here]({{page.url}}#setting-up-client-and-server).

Then I followed [the sshd configrations on the server]({{page.url}}#ssh-configuration-server) and did some modifications in the `sshd_config` file:

- On `line 14` I changed the ssh Port to 22 (Nobody can access the ssh service on my virtual machine without reaching my main server, so if the attacker is already on the main server nothing matters anymore :-D).
- I also **deleted** `line 62` about allowing tcp forwarding (`AllowTcpForwarding yes`), because it is unlikely that I will have nested VMs in the near future so I don't need to forward ssh requests to somebody else.

Of course I also changed the user `jan-server` to `host` as this is my username on the `host-vm`.

I followed the creation of the user group `ssh-user` for allowing ssh login and integrated the Google Authenticator setup thereafter.

At the end I had to reload the `sshd` config: `doas rcctl reload sshd`.

Now also the `host-vm` accepts the same ssh-key that was generated for the main server.

### Access virtual machines via ssh on my workstation

For an easy connection to my virtual machines from my workstation I added some lines to my `~/.ssh/config` file (for each vm):

~~~~ {.bash .numberLines startFrom="1"}
# This block is for ssh connection when I'm in the local network:
Host host-vm-local
	Port 22
	HostName 192.168.30.2
	ProxyCommand ssh -A jan-server@192.168.1.250 -p 13423 -W %h:%p
	User host 

# This block is for ssh connection when I'm at a remote place:
Host host-vm-remote
	Port 22
	HostName 192.168.30.2
	ProxyCommand ssh -A jan-server@hermes-technology.de -p 13423 -W %h:%p
	User host 
~~~~

- *Line 3*: The ssh port on the virtual machine.
- *Line 4*: The local IP of the virtual machine as reachable from the main server.
- *Line 5*: Enables the forwarding of the ssh request to the virtual machine.
- *Line 6*: The user on the virtual machine.

Logging in to virtual machines from my workstation now can easily be done by executing e.g. `ssh host-vm-local`.

Make PF ban IPs that do malicious ssh attempts
-----------------------------------------------

I wanted to block certain IPs from reconnecting via ssh if there were too many attempts with wrong credentials or if those attempts have a frequency that exceeded a certain limitation.

So in short I wanted to react to brute force attackers like `fail2ban` does.

In addition I want those addresses to expire after a certain amount of time.

### Enable blocking of bruteforcers

For this task I had to modify the `/etc/pf.conf` and reload the firewall configuration.

I added a table that is persistent and can be updated with new members:

```bash
table <bruters> persist
```

I told `pf` that IPs listed in this list should be blocked by the server (this rule should be inserted early in your ruleset):

```bash
block quick from <bruters>
```

Then I created a rule to update the brutes table for general connection attempts (not only ssh):

```bash
pass inet proto tcp from any to $localnet port $services \
	flags S/SA keep state \
	(max-src-conn 80, max-src-conn-rate 15/5, \
	overload <bruters> flush global)
```

- `max-src-conn 80` limits the maximum number of simultaneous TCP connections on my tcp services to 80.
- `max-src-conn-rate 15/5` limits the rate of new connections over a time interval to 15 connections in 5 seconds.

This will allow 80 connections from the same source and a connection rate of 15 connections in 5 seconds. Connections exceeding this limit will be added to the `bruters` table and are blocked from any connection to my server until they are removed from the `bruters` table.

Then I added another rule early in my ruleset that specifically blocks ssh bruteforcers. This rule is a little bit stricter on its limits:

```
pass quick proto tcp from any to any port 13423 \
        flags S/SA keep state \
        (max-src-conn 5, max-src-conn-rate 5/3, \
        overload <bruters> flush global)
```

### Enable expiration of bruterforcers over time

For expiring IP addresses in the `bruters` table I added a cron job into the crontab file:

```bash
# /etc/crontab
@daily root pfctl -t brutes -T expire 86400
```

This cronjob will be executed daily and remove entries in the `bruters` table that exceed the duration of presence for 86400 seconds (24 hours).

Conclusion
----------

Now I'm able to login to ssh sessions from my workstation, only using my ed25519 key and the Google Authenticator prompt as second factor.

SSH sessions can be opened as easy as:

```bash
# for server from local network
ssh server-local

# for server from remote network
ssh server-remote

# for vms from local network (exchange <vm> with e.g. host-vm as showed above)
ssh <vm>-local

# for vms from remote network
ssh <vm>-remote
```

"Insecure" plain password connections are not supported anymore.

Failing ssh connections will remembered and according IPs will be banned for the specified amounts of time as presented in the last section of this post.

Outlook
-------

I'm not sure yet what I will be writing about in my next post. Maybe I will find out how to use `relayd` as a substitute of `nginx` [for redirecting subdomain requests]({{page.previous.url}}#installing-and-configuring-nginx-on-the-host-vm) to my local VM IPs, then I will probably be writing about that (there is also [an open question](https://serverfault.com/questions/856807/openbsd-how-to-use-relayd-and-httpd-for-redirecting-subdomain-requests) for this on stack exchange). Maybe I will also write about a backup utility that I set up as a cronjob for doing frequent backups of my main-server and the VMs.

But until then I'm happy about comments and any suggestions that you have for me, "see" you soon.

Jan
