---
layout: post
comments: true
title:  "A simple first server"
project:
  name: My OpenBSD server
  part: 2
  banner:
    img: my-openbsd-server-project-banner.svg.png
    width: 250px;
    height: 250px;
    thumbnail: my-openbsd-server-project-banner-thumbnail.svg.png
date:   2017-06-06 17:11:00 +0100
categories: openbsd server
excerpt: I'm setting up a simple server in OpenBSD. This includes installing OpenBSD and configuring the network. Also I needed to enable port-forwarding on my home router and establish a dyndns service for updating my domain to point on the frequenctly changing IP.
---
Hello, last time I showed a sketch of my server infrastructure without explaining anything really. That's where I'm going to start in this post. As a reminder I will include the picture again:

<figure markdown="1">
<figcaption>
<i>Figure 1: Server Infrastructure</i>
</figcaption>
![Server Infrastructure]({{site.url}}/assets/server-sketch.svg.png 'Figure 1: Server Infrastructure')
</figure>

At first I would like to give a quick overview of what I wanted to achieve with this infrastructure: I wanted to encapsulate as much as possible in virtual machines, that will care about the specific tasks my server should provide in the end. Right now I have a dedicated VM for this blog I'm writing, a cloud, a gitlab server and the host VM which cares about redirecting the different subdomain requests.

But for an easy explanation I will try to start much simpler - actually I will start the same way that I did a few weeks ago. I will just have my OpenBSD server that shows a simple "Hello world!" html page. Starting with this simple setup I will develope the above infrastructure in small steps during the next posts.

For better understanding and visualization I will always backup the explanations with some figures. Throughout those figures I will try to use the format as shown in *Figure 2* when necessary.

<figure markdown="1">
<figcaption>
<i>Figure 2: Component Box</i>
</figcaption>
![Component Box]({{site.url}}/assets/component-box.svg.png 'Figure 2: Component Box'){:width="340px" height="150px"}
</figure>

The task for today
------------------
As I already mentioned, today I will only create a simple http server on OpenBSD which is actually a very straight forward task. *Figure 3* shows the different components that are needed to achieve the desired functionality: 

At first I need to install OpenBSD somewhere and connect its NIC (Network Interface Card) to my router. For this first step I could also have installed it in a VM with virtualbox for example.

Thereafter I need to enable port-forwarding and assign a static ip to the server in the router's interface (I had to open the browser and go to 192.168.1.1 for the router's webinterface).

To always be sure to get the same static ip address from my router I will also configure the interface to use a static ip instead of dhcp.

After enabling and configuring the httpd server I will be able to reach the webserver from anywhere in the www, provided that I know my public ip.
So the last step would be to make the public ip reachable through a domain name.

<figure markdown="1">
<figcaption>
<i>Figure 3: First steps - Simple server</i>
</figcaption>
![The first step]({{site.url}}/assets/step1-sketch.svg.png 'Figure 3: First steps - Simple server')
</figure>

OpenBSD server - Install and set up
-----------------------------------

As you heard I want to build the whole server-setup using OpenBSD. This was my OS of choice, because it has a strong focus on security. So coming from the Linux world I had to learn a little bit about the workings of a BSD system, and just to anticipate it: I was positively surprised about the celarliness and easyness I had to deal with.

Installing OpenBSD is easy and fast. I just had to follow the instructions at [their homepage](https://www.openbsd.org/faq/faq4.html) and everything was set up well. After installing make sure that your system is connected to your LAN.

<div class=fromTheFuture >

+--------------------------------------------------------------------------------------------------------------------------------------+
| **Doc, about the future...**                                                                                                         |
+======================================================================================================================================+
| I also have an [installation guide]({{page.next.url}}#guided-installation-of-openbsd-for-the-host-vm) now                            |
| that you can read and see how I did react to each of the installation questions for the installation of a virtual machine on OpenBSD.|
+--------------------------------------------------------------------------------------------------------------------------------------+

</div>

After installing I also setup the `sudo` equivalent of OpenBSD called `doas`. For it to work just create a file called `/etc/doas.conf` and insert these lines:

```bash
permit persist :wheel ## permit all users from group wheel to gran root access via doas and let it pe persistent during the terminal session
permit nopass keepenv root
```

If you have problems setting up a working package mirror for OpenBSD, I found the easiest and always working method of creating a specific file in the `/etc/` directory, and filling it with my chosen mirror:

```bash
doas touch /etc/installurl
doas echo "https://ftp.eu.openbsd.org/pub/OpenBSD/" > /etc/installurl
```

Naturally you can choose any OpenBSD mirror you like. There is a list of possible mirrors located [here](https://www.openbsd.org/ftp.html).

### Some nice configurations ###

I also added some nice configuration for better working with the system:

```bash
## /etc/doas.conf
permit persist setenv { -ENV PS1=$DOAS_PS1 SSH_AUTH_SOCK } :wheel
permit nopass keepenv root
```

Adding these lines to your user's and your root's `.profile` file:

```bash
## /root/.profile
PS1="[\t - \d]\n\u@\H:\w[\s]# "
export PS1
export HISTFILE=~/.sh_history
```

```bash
## /home/user/.profile
PS1="[\t - \d]\n\u@\H:\w[\s]\n$ "
export PS1
DOAS_PS1="[\t - \d]\n\u@\H:\w[\s]\n# "
export DOAS_PS1
export HISTFILE=~/.sh_history
```

- `export HISTFILE...`: makes the history persistent so its not lost after each session.
- PS1: the terminal prompt
- DOAS_PS1: the terminal prompt when executing doas


### Configuring the NIC (static ip) ###

For proper functionality its easier to configure the OpenBSD server to obtain a static ip instead of relying on the router's dhcp service. To achieve this, I had to change two files: `/etc/hostname.em0` and `/etc/mygate`. The name of your interface could be different which would also result in another filename `/etc/hostname.your-interface-name`. In a OpenBSD VM the interfaces are called vio0 for example. Resulting in the filename to be `hostname.vio0`.

```bash
## /etc/hostname.em0 ##
inet static 192.168.1.250 255.255.255.0 # this will enable the static ip address 192.168.1.250 with a 255.255.255.0 netmask
```

After configuring the static ip I had to make sure that there is a file called `/etc/mygate` which wasn't present because I installed my OpenBSD Box with dhcp enabled on my NIC.
I created the file as root and wrote my routers ip as the single line in the file.

```bash
## /etc/mygate ## 
192.168.1.1 # one line that specifies the gateway (in my case 192.168.1.1)
```

Router configuration
--------------------
As every router and brand has its own way of configuration, I cannot tell you much about how you will be able to achieve this task. So I will roughly tell you how I did it (I am ommiting the router name and brand, as it would expose potential vulnerabilities that it could have that I don't know of).
For all configurations I had to open the web interface of my router at 192.168.1.1 and enter my password.

### Static IP
For the static ip I had to browse to a category called *LAN* where I could assign static IP addresses to specific link layer adresses (MACs). So supposed that your NIC has the MAC 12:34:56:78:9A:BC you would tell your router to assign the desired static ip to that MAC. In my case I assigned the ip 192.168.1.250.

### Port-forwarding
Port-forwarding at my routers interface could be found at Homenet -> Port Forwarding. At this section I could create Port-forwarding rules for IPv4 and IPv6. I only created a rule for IPv4.
I had to choose a service name: HTTP, the computer to forward the port to: 192.168.1.250, the transport protokoll: TCP and the Port range: 80-80.

*Attention*: When I created the rule I also had to enable a checkbox to activate that rule. Apart from the rules checkbox I also had to enable Port-forwarding as a whole in another dedicated checkbox on that site. This did cost me a little headache in the beginning because I didn't see the specific rules checkbox when creating the port-forwarding rule and I wondered why the port-forwarding didn't work.

Domainname and DDNS
-------------------

In this section I will explain how I bought a domain name and enabled a DDNS client to update my ip changes to that domain name.

### Getting a domain

There are a lot of domain registration services that you could use. But not all of them have a dynamic dns service included. I chose [Strato](https://www.strato.de) which is a german hosting service. I bought the domain-name hermes-technology.de.

You could also first try things out with a free service like [noip](https://www.noip.com/).

### Integrating the domain in the server

For proper configuration of the server and name resolving I configured my OpenBSD system to use the new domain name as the hostname.

For this to work properly, I had to edit the following files (the explanation for the configuration is commented inline):

```bash
## /etc/myname ##
hermes-technology.de # one line that specifies the symbolic name of the host machine 
```
```bash
## /etc/resolv.conf ##
nameserver 192.168.1.1 # the nameserver the resolver should query
lookup file bind # gethostbyname and gehostbyaddr should lookup in /etc/hosts first (file) and then ask the provided nameserver (bind)
```
```bash
## /etc/hosts ##
# The first two lines are the defaults, the last line again specifies my domain name with my static ip address
# These names will be used by the resolver that is configured to lookup in this file via /etc/resolv.conf
127.0.0.1   localhost
::1     localhost
192.168.1.250  hermes-technology.de
```

#### Making the public ip reachable from the internet (DDNS)

My IPS, like most of the private Internet connections, frequently changes my public ip so I cannot assing a static ip to my domain name. A service to circumvent this problem is a so called dynamic DNS client, or short DDNS client on the server side. There are **two possibilites** for this to work: Either my **router itself has a DDNS client** that can resolve the host that I have bought my domainname from, or I will **install a dedicated DDNS client** on my OpenBSD server.

As mentioned before, I bought my domain at the german service called Strato (www.strato.de). At this time my router had a few DDNS hosts that it could make a ddns update for, but Strato was not one of them. So I was left with the second choice: Installing a DDNS client on the OpenBSD server and configuring it to forward ip changes to the strato service.

I decided to install the ddns client called ddclient which is already available in the official ports of OpenBSD. So it was as easy as calling `pkg_add ddclient` for installing it. Thereafter I was left with the configuration file in /etc/ddclient/ddclient.conf. I appended some lines at the bottom of the `ddclient.conf` file, so that it would look like this:

```bash
## /etc/ddclient/ddclient.conf

## These lines were enabled by default
daemon=600              # check every 300 seconds
syslog=yes              # log update msgs to syslog
mail=root               # mail all msgs to root
mail-failure=root           # mail failed update msgs to root
pid=/var/run/ddclient/ddclient.pid  # record PID in file.
ssl=yes                 # use ssl-support.  Works with
                    # ssl-library

## ... There were some commented lines in between

# This is the chunk I appended:
use=web
protocol=dyndns2
server=dyndns.strato.com
login=hermes-technology.de
password=somepassword
hermes-technology.de
```

The configuration above has a few components:
- The first `use=web` means, that the ddns server is reached through the internet.
- `protocol=dyndns2` specifies the ddns protocol that the destination server uses.
- `login=hermes-technology.de` is my login name for he server as provided by strato
- `password=somepassword` is the specific password for the ddns service
- the last lines of the configuration specifies the domain names that should receive the DDNS updates I only update my main domain for DDNS as I have simple CNAME entries for all other subdomains that are thus reached through the same ip address as the main domain.

I also enabled the ddclient Daemon in the service manager:
```bash
doas rcctl enable ddclient
```
and started it:
```bash
doas rcctl start ddclient
```

Start httpd and show your website
---------------------------------

At last I wanted to show a simple static html "Hello World!" page on my domain. For this to work I had to configure the `httpd` daemon, which is a simple http server from OpenBSD based on Apache.


```bash
## /etc/httpd.conf
ext_if="*" ## any interface is the external interface.. including my em0

server "hermes-technology.de" {
        
        listen on $ext_if port 80 ## listen on all interfaces on port 80
        
        root "/htdocs/hermes-technology.de" ## make /var/www/htdocs/hermes-technology.de my root website directory
}

types {
        include "/usr/share/misc/mime.types"
}
```

After configurin the daemon I had to insert a `index.html` in my website's directory:
```bash
cd /var/www/htdocs/hermes-technology.de/
```
```bash
touch index.html
```
```bash
echo "Hello World!" > index.html
```
```bash
doas rcctl enable httpd
doas rcctl start httpd
```

Now my "Hello World!" page will be shown at hermes-technology.de.

Outlook
-------

In the next post I will setup an OpenBSD virtual machine on the main server that receives the http requests. This includes configuring our own DNS server `unbound` and setting up the firewall `pf` (see Figure 1).
