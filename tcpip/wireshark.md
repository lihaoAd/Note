```

```

```c
ip.src eq 192.168.1.107 or ip.dst eq 192.168.1.107  # 过滤IP，如来源IP或者目标IP等于某个IP
    
ip.addr eq 192.168.1.107  # 都能显示来源IP和目标IP
    
tcp.port eq 80 // 不管端口是来源的还是目标的都显示

tcp.port == 80

tcp.port eq 2722

tcp.port eq 80 or udp.port eq 80

tcp.dstport == 80 // 只显tcp协议的目标端口80

tcp.srcport == 80 // 只显tcp协议的来源端口80

udp.port eq 150
    
tcp.port >= 1 and tcp.port <= 80
    
```



## 过滤协议

````c
tcp

udp

arp

icmp

http

smtp

ftp

dns

msnms

ip

ssl

oicq

bootp
    
排除arp包，如!arp   或者   not arp
````

## 过滤MAC

````c
eth.dst == A0:00:00:04:C5:84 // 过滤目标mac

eth.src eq A0:00:00:04:C5:84 // 过滤来源mac

eth.dst==A0:00:00:04:C5:84

eth.dst==A0-00-00-04-C5-84

eth.addr eq A0:00:00:04:C5:84 // 过滤来源MAC和目标MAC都等于A0:00:00:04:C5:84的
````

## 包长度过滤



``````c
udp.length == 26 这个长度是指udp本身固定长度8加上udp下面那块数据包之和

tcp.len >= 7   指的是ip数据包(tcp下面那块数据),不包括tcp本身

ip.len == 94 除了以太网头固定长度14,其它都算是ip.len,即从ip本身到最后

frame.len == 119 整个数据包长度,从eth开始到最后
``````

## http模式过滤

```
http.request.method == “GET”

http.request.method == “POST”

http.request.uri == “/img/logo-edu.gif”

http contains “GET”

http contains “HTTP/1.”
```

