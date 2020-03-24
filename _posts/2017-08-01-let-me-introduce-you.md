---
layout: post
title: Let me introduce you
comments: true
project:
  name: Rob the Robot
  part: 1
  banner:
    img: rob-the-robot-banner-header.svg.png
    width: 250px;
    height: 250px;
date:   2017-08-01 17:11:00 +0100
categories: arduino robot maker udooneo
excerpt: I've always wanted to build a robot, but yet I did not build one! In this introduction I will shortly write about what I want to do about this dilemma and the components I have in mind to solve it.
---

And now for something completely different - Number 1... the larch.

![The larch]({{size.url}}/assets/the-larch.jpg 'the larch')

... Number 3... the robot.

Hello dear reader,

I will now write about something completely different. It's not about a larch, but I would like to build a robot! For backing up my explanations I include a figure that shows a rough overview on what this project is about, and how I would like to achieve my goals:

<figure markdown="1">
<figcaption>
<i>Figure 1: Rob's concept</i>
</figcaption>
![Robs concept]({{site.url}}/assets/rob-the-robot-env.svg.png 'Figure 1: Robs concept')
</figure>

I decided to distinguish between three ability domains for Rob:

Firstly, there is the **Arduino microcontoller** (ARM Cortex-M4), which is responsible for all critical controlling that has to be done in real time. I also added the **Adafruit Motorshield** on my Udoo Neo board for an easy way to control any kind of motor that I want to integrate for the robot.
Examples for those critical tasks would be a balancing controller or an automatic halt-system that fires before hitting walls or falling into an abyss. The balancing controller will, as soon as the robot will be running on two wheels, stabilize R.O.B. in real-time. For those tasks I will add specific parts like an array of ultrasonic sensors for distance queries or use existing components on the board like the magnetometer, accelerometer and the gyroscope.

Secondly, also on the Udoo Neo board, there is the **ARM Cortex-A9**. The software running on there will perform simple computations and provide an interface for interactions with Rob. By way of example I could think about path finding algorithms and simple data storage and retrieval. It will enable the possibility to interact with the robot via WLAN or bluetooth. The Cortex-M4 and Cortex-A9 can communicate via an i²c bus.

At last I will also integrate the **server**. So while being on this project I will also need the functionality of my server that I'm building in the "My OpenBSD Server" project. The server will be performing more expensive computations that include the establishment of neuronal networks for voice or face recognition.

So all in all the basic mechanical and sensor functionality will run on the microcontroller, more sophisticated operations and WLAN interfacing will be done with the arm, and the server provides some kind of AI.

While working on this project, the server I built is not out of my focus, I will continue to add more functionality and document my configurations in this blog. At the moment I also have to work on two non-private projects that consume a lot of resources, so I will be a little bit thwarted on the OpenBSD server and robot project for the next two month.

So I hope to write to you soon, until next post.
