## 视频所有类型,只看不下载

````
python -m youtube_dl -F https://www.youtube.com/watch?v=SpZqeVqtMKk&t=164s
````

![image-20210202140953807](.\img\image-20210202140953807.png)



`````
python -m youtube_dl --list-formats "https://www.youtube.com/watch?v=SpZqeVqtMKk&t=164s"
`````

![image-20210202141150906](.\img\image-20210202141150906.png)

## 下载指定质量的视频和音频并自动合并

由于YouTube的1080p及以上的分辨率都是音视频分离的,所以我们需要分别下载视频和音频,如果系统中安装了ffmpeg的话, youtube-dl 会自动合并下下好的视频和音频, 然后自动删除单独的音视频文件

```
youtube-dl -f [format code] [url]
```

```
 python -m youtube_dl -f 137+140 "https://www.youtube.com/watch?v=SpZqeVqtMKk&t=164s"
```



![image-20210202142223321](.\img\image-20210202142223321.png)