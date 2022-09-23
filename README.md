# NGINX Plus unprivileged container

This is a docker file for building an unprivileged NGINX Plus container.

This builds NGINX Plus, so you'll need to copy your nginx repo keys into the build folder, and then run with:
```
DOCKER_BUILDKIT=1 docker build --secret id=nginx-key,src=nginx-repo.key --secret id=nginx-crt,src=nginx-repo.crt -t nginxplus:latest .
```

## Usage with NIM/NMS/ACM

The build process can install the NGINX Agent if you provide your NIM/ACM hostname in the NGINX_NMS_HOST environment var.

```
ENV NGINX_NMS_HOST  "nim1.management.network.com"
```

## Usage with NAP

The build process can install and setup NAP to run alongside NGINX Plus if you provide the NAP package names 
in the NGINX_NAP_PKGS environment variable.

```
ENV NGINX_NAP_PKGS  "app-protect app-protect-attack-signatures app-protect-threat-campaigns"
```


