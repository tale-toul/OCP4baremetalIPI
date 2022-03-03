# Technical details about the nginx reverse proxy configuration

## Reference NGINX documentation
* [ngx_http_proxy module](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
* [Regular expresions in NGINX](https://www.nginx.com/blog/regular-expression-tester-nginx/)
* [NGINX Maps](https://johnhpatton.medium.com/nginx-map-comparison-regular-express-229120debe46)
* [NGINX Reverse Proxy](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)
* [ngx_http_sub module](http://nginx.org/en/docs/http/ngx_http_sub_module.html)

The reverse proxy contains virtual servers for accessing:

* The API endpoint
* The secure application routes
* The non secure application routes

Most of the virtual servers make use of the variable **$host_head**.  A [map](http://nginx.org/en/docs/http/ngx_http_map_module.html#map) is used to define this variable.

The map takes the [$host](http://nginx.org/en/docs/http/ngx_http_core_module.html#var_host) variable defined by NGINX, which contains the host part in the URL used by the client, and applies a regular expression to it to extract the first part of that hostname, the result is assigned to the variable $host_head that can then be used throughout the rest of the configuration.  This map is applied to every request received by the the virtual servers that use the $host_head variable.
```
map $host $host_head {
  "~^(?<head>[^.]+)\..*" $head;
  default $host;
}
```

An example will help clarify how the map works

For the URL **http://httpd-example-bandido.apps.bell.example.com/index.html**

The $host variable will contain **httpd-example-bandido.apps.bell.example.com**

The regular expression defines a named capture group named $head `(?<head>[^.]+)`.  This capture group will match from the beginning of the name up to the first dot, the resulting value will be returned, in the example __httpd-example-bandido__

The virtual server for non secured application routes listens on port 80 (http), and accepts requests with a Host header in the domain **\*.apps.ocp4.redhat.com**, for any resource under root (/).  Requests will be forwarded to the default ingress controller IP address using the same http protocol (http://192.168.30.110) and the Host header is changed to use the internal DNS domain.

The Host header is modified from the original because the Openshift cluster uses it in its own virtual server definitions, and it does not understand the external DNS domain.
```
server {
  listen 80;
  server_name *.apps.ocp4.redhat.com;

  location / {
    proxy_set_header Host $host_head.apps.ocp4.tale.net;
    proxy_pass http://192.168.30.110;
  }
}
```
The change in the host header is shown in the following example:

For the URL **http://httpd-example-bandido.apps.bell.example.com/index.html**  the Host header is changed to the first part of the hostname, extracted by the map and the domain .ocp4.redhat.com, resulting in **Host: httpd-example-bandido.ocp4.redhat.com**

The virtual server for secured application routes listens on port 443 (https), and accepts requests with a Host header in the domain **\*.apps.ocp4.redhat.com**, for any resource under root (/).  Requests will be forwarded to the default ingress controller IP address using the same https protocol (https://192.168.30.110) and the Host header is changed to use the internal DNS domain.

The x509 certificate used to encrypt the connections and some additional SSL configuration directives are specified in the configuration.

The Host header is modified from the original because the Openshift cluster uses it in its own virtual server definitions, and it does not understand the external DNS domain. The mechanism is the same as explained for the non secure routes virtual server, but here SNI is also updated and sent to the Openshift cluster with the directives `proxy_ssl_server_name on` and `proxy_ssl_name $host_head.apps.ocp4.tale.net`; this is required because the SSL connections don't know about the Host header until after the connection has been fully established.
```
server {
  listen 443 ssl default_server;

  server_name *.apps.ocp4.redhat.com;
  ssl_certificate "/etc/pki/nginx/ocp-apps.crt";
  ssl_certificate_key "/etc/pki/nginx/private/ocp-apps.key";
  ssl_session_cache shared:SSL:1m;
  ssl_session_timeout  10m;
  ssl_ciphers PROFILE=SYSTEM;
  ssl_prefer_server_ciphers on;

  location / {
    proxy_set_header Host $host_head.apps.ocp4.tale.net;
    proxy_ssl_server_name on;
    proxy_ssl_name $host_head.apps.ocp4.tale.net;
    proxy_pass https://192.168.30.110;
  }
}
```
Another virtual server for secured application accepts requests in the domain **\*.apps.ocp4.tale.net**, its configuration is similar to the one explained above, but it is used to access the web console and the oauth service.

The last virtual server definition is used to access the API endpoint, accepts requests in port 6443 and for any resource in the hostname __api.ocp4.redhat.com__.  Requests are forwarded to the API endpoint's IP in the Openshift cluster and port 6443 (https://192.168.30.100:6443).  That endpoint does not support virtual servers of its own so no need to send a specific Host header or even the SNI name.
```
server {
  listen 6443 ssl;

  server_name api.ocp4.redhat.com;
  ssl_certificate "/etc/pki/nginx/ocp-api.crt";
  ssl_certificate_key "/etc/pki/nginx/private/ocp-api.key";
  ssl_session_cache shared:SSL:1m;
  ssl_session_timeout  10m;
  ssl_ciphers PROFILE=SYSTEM;
  ssl_prefer_server_ciphers on;
 
  location / {
    proxy_pass https://192.168.30.100:6443;
  }
}
```
