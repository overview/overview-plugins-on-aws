This repository stores all our plugin definitions for Amazon Web Services.

Our plugins run in Amazon EC2 Container Service. All plugins share a single
Elastic Load Balancer. That means they all run on different ports. And _that_
means we need One Central Place to store all the port numbers. Voila.

Plugin port numbers
-------------------

Overview plugins are all Docker containers. They all listen on port `3000`.

Elastic Beanstalk will listen on a separate port per instance, in the range
`3001-3999`. That will forward to the actual EC2 _instances_, which will wire
up port `X` to point to `3000`.

See `plugins.txt` for the comprehensive list of port numbers.

Adding a new plugin
-------------------

First, publish the plugin to Docker Hub, in the `overview` account.

In this example, the Docker image is `overview/overview-foobar` and we'll
allocate port `3210`. We'll limit the image to `1000MB` of memory.

Next:

1. `./register.sh overview-foobar 3210 1000`
2. `./deploy.sh overview-foobar`
3. Commit and push

Please commit early, so we can avoid port number conflicts.
