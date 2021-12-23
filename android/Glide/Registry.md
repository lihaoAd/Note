## ModelLoaderRegistry

```java
public interface ModelLoaderFactory<T, Y> {

  /**
   * Build a concrete ModelLoader for this model type.
   *
   * @param multiFactory A map of classes to factories that can be used to construct additional
   *     {@link ModelLoader}s that this factory's {@link ModelLoader} may depend on
   * @return A new {@link ModelLoader}
   */
  @NonNull
  ModelLoader<T, Y> build(@NonNull MultiModelLoaderFactory multiFactory);

  /** A lifecycle method that will be called when this factory is about to replaced. */
  void teardown();
}
```



```java
append(File.class, InputStream.class, new FileLoader.StreamFactory())
append(File.class, File.class, UnitModelLoader.Factory.<File>getInstance())    
append(File.class, ByteBuffer.class, new ByteBufferFileLoader.Factory())    
append(File.class, ParcelFileDescriptor.class, new FileLoader.FileDescriptorFactory())
    
append(int.class, InputStream.class, resourceLoaderStreamFactory)
append(int.class, Uri.class, resourceLoaderUriFactory)   
append(int.class, ParcelFileDescriptor.class, resourceLoaderFileDescriptorFactory)
append(int.class, AssetFileDescriptor.class, resourceLoaderAssetFileDescriptorFactory)    

append(Integer.class, InputStream.class, resourceLoaderStreamFactory)
append(Integer.class, Uri.class, resourceLoaderUriFactory)
append(Integer.class, ParcelFileDescriptor.class, resourceLoaderFileDescriptorFactory)
append(Integer.class, AssetFileDescriptor.class, resourceLoaderAssetFileDescriptorFactory)    

append(String.class, ParcelFileDescriptor.class, new StringLoader.FileDescriptorFactory())
append(String.class, InputStream.class, new DataUrlLoader.StreamFactory<String>())    
append(String.class, AssetFileDescriptor.class, new StringLoader.AssetFileDescriptorFactory())    
append(String.class, InputStream.class, new StringLoader.StreamFactory()) 

append(Uri.class, File.class, new MediaStoreFileLoader.Factory(context))    
append(Uri.class, Uri.class, UnitModelLoader.Factory.<Uri>getInstance())    
append(Uri.class, AssetFileDescriptor.class,new UriLoader.AssetFileDescriptorFactory(contentResolver))    
append(Uri.class, ParcelFileDescriptor.class,new UriLoader.FileDescriptorFactory(contentResolver))
append(Uri.class, InputStream.class, new MediaStoreImageThumbLoader.Factory(context))
append(Uri.class, InputStream.class, new MediaStoreVideoThumbLoader.Factory(context))    
append(Uri.class, InputStream.class, new AssetUriLoader.StreamFactory(context.getAssets()))    
append(Uri.class, InputStream.class, new DataUrlLoader.StreamFactory<Uri>())    
append(Uri.class, InputStream.class, new UriLoader.StreamFactory(contentResolver))      
append(Uri.class, InputStream.class, new UrlUriLoader.StreamFactory())    
    
append(URL.class, InputStream.class, new UrlLoader.StreamFactory())    

append(Bitmap.class, Bitmap.class, UnitModelLoader.Factory.<Bitmap>getInstance())

append(Drawable.class, Drawable.class, UnitModelLoader.Factory.<Drawable>getInstance())

append(byte[].class, ByteBuffer.class, new ByteArrayLoader.ByteBufferFactory())
append(byte[].class, InputStream.class, new ByteArrayLoader.StreamFactory())    
  
append(GlideUrl.class, InputStream.class, new HttpGlideUrlLoader.Factory())
    
    
```

## EncoderRegistry

将数据持久化存储

```java
/**
 * An interface for writing data to some persistent data store (i.e. a local File cache).
 *
 * @param <T> The type of the data that will be written.
 */
public interface Encoder<T> {
  /**
   * Writes the given data to the given output stream and returns True if the write completed
   * successfully and should be committed.
   *
   * @param data The data to write.
   * @param file The file to write the data to.
   * @param options The set of options to apply when encoding.
   */
  boolean encode(@NonNull T data, @NonNull File file, @NonNull Options options);
}
```



```java
append(InputStream.class, new StreamEncoder(arrayPool))
append(ByteBuffer.class, new ByteBufferEncoder())
```



## ResourceDecoderRegistry

```java
/**
 * An interface for decoding resources.
 *
 * @param <T> The type the resource will be decoded from (File, InputStream etc).
 * @param <Z> The type of the decoded resource (Bitmap, Drawable etc).
 */
public interface ResourceDecoder<T, Z> {

  boolean handles(@NonNull T source, @NonNull Options options) throws IOException;

  @Nullable
  Resource<Z> decode(@NonNull T source, int width, int height, @NonNull Options options)
      throws IOException;
}
```

```java
append(Registry.BUCKET_BITMAP, ByteBuffer.class, Bitmap.class, byteBufferBitmapDecoder)
append(Registry.BUCKET_BITMAP, InputStream.class, Bitmap.class, streamBitmapDecoder)
append(Registry.BUCKET_BITMAP, ParcelFileDescriptor.class, Bitmap.class, new ParcelFileDescriptorBitmapDecoder(downsampler))
append(Registry.BUCKET_BITMAP, ParcelFileDescriptor.class, Bitmap.class, parcelFileDescriptorVideoDecoder)   
append(Registry.BUCKET_BITMAP, AssetFileDescriptor.class,  Bitmap.class, VideoDecoder.asset(bitmapPool))
append(Registry.BUCKET_BITMAP, Bitmap.class, Bitmap.class, new UnitBitmapDecoder())   
append(Registry.BUCKET_GIF, InputStream.class, GifDrawable.class, new StreamGifDecoder(imageHeaderParsers, byteBufferGifDecoder, arrayPool))  
append(Registry.BUCKET_BITMAP_DRAWABLE,InputStream.class, BitmapDrawable.class,new BitmapDrawableDecoder<>(resources, streamBitmapDecoder))    
append(Registry.BUCKET_BITMAP_DRAWABLE, ByteBuffer.class, BitmapDrawable.class, new BitmapDrawableDecoder<>(resources, byteBufferBitmapDecoder)) append(Registry.BUCKET_GIF, ByteBuffer.class, GifDrawable.class, byteBufferGifDecoder)
    
```



## ResourceEncoderRegistry



```java
/**
 * An interface for writing data from a resource to some persistent data store (i.e. a local File
 * cache).
 *
 * @param <T> The type of the data contained by the resource.
 */
public interface ResourceEncoder<T> extends Encoder<Resource<T>> {
  // specializing the generic arguments
  @NonNull
  EncodeStrategy getEncodeStrategy(@NonNull Options options);
}


/**
 * Details how an {@link com.bumptech.glide.load.ResourceEncoder} will encode a resource to cache.
 */
public enum EncodeStrategy {
  /**
   * Writes the original unmodified data for the resource to disk, not include downsampling or
   * transformations.
   */
  SOURCE,

  /** Writes the decoded, downsampled and transformed data for the resource to disk. */
  TRANSFORMED,

  /** Will write no data. */
  NONE,
}
```

```java
append(Bitmap.class, bitmapEncoder)
append(GifDrawable.class, new GifDrawableEncoder())
append(BitmapDrawable.class, new BitmapDrawableEncoder(bitmapPool, bitmapEncoder))
```

