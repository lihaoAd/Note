## IInterface

frameworks/base/include/binder/IInterface.h

```c++
class IInterface : public virtual RefBase
{
public:
            IInterface();
            sp<IBinder>         asBinder();
            sp<const IBinder>   asBinder() const;
            
protected:
    virtual                     ~IInterface();
    virtual IBinder*            onAsBinder() = 0;
};
```



## BBinder

frameworks/base/include/binder/Binder.h

```c++
class BBinder : public IBinder
{
public:
                        BBinder();

    virtual const String16& getInterfaceDescriptor() const;
    virtual bool        isBinderAlive() const;
    virtual status_t    pingBinder();
    virtual status_t    dump(int fd, const Vector<String16>& args);

    virtual status_t    transact(   uint32_t code,const Parcel& data,Parcel* reply,uint32_t flags = 0);

    virtual status_t    linkToDeath(const sp<DeathRecipient>& recipient,void* cookie = NULL, uint32_t flags = 0);

    virtual status_t    unlinkToDeath(  const wp<DeathRecipient>& recipient,
                                        void* cookie = NULL,
                                        uint32_t flags = 0,
                                        wp<DeathRecipient>* outRecipient = NULL);

    virtual void        attachObject(   const void* objectID, void* object,void* cleanupCookie,object_cleanup_func func);
    virtual void*       findObject(const void* objectID) const;
    virtual void        detachObject(const void* objectID);

    virtual BBinder*    localBinder();

protected:
    virtual             ~BBinder();

    virtual status_t    onTransact( uint32_t code,const Parcel& data,Parcel* reply, uint32_t flags = 0);

private:
                        BBinder(const BBinder& o);
            BBinder&    operator=(const BBinder& o);

    ...
};
```

## BpBinder

frameworks/base/include/binder/BpBinder.h

```c++
class BpBinder : public IBinder
{
public:
                        BpBinder(int32_t handle);

    inline  int32_t     handle() const { return mHandle; }

    virtual const String16&    getInterfaceDescriptor() const;
    virtual bool        isBinderAlive() const;
    virtual status_t    pingBinder();
    virtual status_t    dump(int fd, const Vector<String16>& args);

    virtual status_t    transact(   uint32_t code, const Parcel& data,Parcel* reply,uint32_t flags = 0);

    virtual status_t    linkToDeath(const sp<DeathRecipient>& recipient, void* cookie = NULL,uint32_t flags = 0);
    virtual status_t    unlinkToDeath(  const wp<DeathRecipient>& recipient,
                                        void* cookie = NULL,
                                        uint32_t flags = 0,
                                        wp<DeathRecipient>* outRecipient = NULL);

    virtual void        attachObject(   const void* objectID,
                                        void* object,
                                        void* cleanupCookie,
                                        object_cleanup_func func);
    virtual void*       findObject(const void* objectID) const;
    virtual void        detachObject(const void* objectID);

    virtual BpBinder*   remoteBinder();

            status_t    setConstantData(const void* data, size_t size);
            void        sendObituary();

   ....

protected:
    virtual             ~BpBinder();
    virtual void        onFirstRef();
    virtual void        onLastStrongRef(const void* id);
    virtual bool        onIncStrongAttempted(uint32_t flags, const void* id);

private:
    const   int32_t             mHandle;

    struct Obituary {
        wp<DeathRecipient> recipient;
        void* cookie;
        uint32_t flags;
    };

            void                reportOneDeath(const Obituary& obit);
            bool                isDescriptorCached() const;

    mutable Mutex               mLock;
            volatile int32_t    mAlive;
            volatile int32_t    mObitsSent;
            Vector<Obituary>*   mObituaries;
            ObjectManager       mObjects;
            Parcel*             mConstantData;
    mutable String16            mDescriptorCache;
};
```



## IBinder

frameworks/base/include/binder/IBinder.h

```c++
class IBinder : public virtual RefBase
{
public:
    enum {
        FIRST_CALL_TRANSACTION  = 0x00000001,
        LAST_CALL_TRANSACTION   = 0x00ffffff,

        PING_TRANSACTION        = B_PACK_CHARS('_','P','N','G'),
        DUMP_TRANSACTION        = B_PACK_CHARS('_','D','M','P'),
        INTERFACE_TRANSACTION   = B_PACK_CHARS('_', 'N', 'T', 'F'),

        // Corresponds to TF_ONE_WAY -- an asynchronous call.
        FLAG_ONEWAY             = 0x00000001
    };

    IBinder();

    virtual sp<IInterface>  queryLocalInterface(const String16& descriptor);

    virtual const String16& getInterfaceDescriptor() const = 0;

    virtual bool            isBinderAlive() const = 0;
    virtual status_t        pingBinder() = 0;
    virtual status_t        dump(int fd, const Vector<String16>& args) = 0;

    virtual status_t        transact(   uint32_t code, const Parcel& data, Parcel* reply, uint32_t flags = 0) = 0;

    class DeathRecipient : public virtual RefBase
    {
    public:
        virtual void binderDied(const wp<IBinder>& who) = 0;
    };

    virtual status_t   linkToDeath(const sp<DeathRecipient>& recipient, void* cookie = NULL, uint32_t flags = 0) = 0;

    virtual status_t    unlinkToDeath(  const wp<DeathRecipient>& recipient,
                                            void* cookie = NULL,
                                            uint32_t flags = 0,
                                            wp<DeathRecipient>* outRecipient = NULL) = 0;

    virtual bool   checkSubclass(const void* subclassID) const;

    typedef void (*object_cleanup_func)(const void* id, void* obj, void* cleanupCookie);

    virtual void attachObject(   const void* objectID, void* object, void* cleanupCookie, object_cleanup_func func) = 0;
    virtual void*           findObject(const void* objectID) const = 0;
    virtual void            detachObject(const void* objectID) = 0;

    virtual BBinder*        localBinder();
    virtual BpBinder*       remoteBinder();

protected:
    virtual          ~IBinder();

private:
};
```



## BpInterface

frameworks/base/include/binder/IInterface.h

```c++
template<typename INTERFACE>
class BpInterface : public INTERFACE, public BpRefBase
{
public:
          BpInterface(const sp<IBinder>& remote);

protected:
    virtual IBinder*            onAsBinder();
};
```



## BnInterface

frameworks/base/include/binder/IInterface.h

```c++
template<typename INTERFACE>
class BnInterface : public INTERFACE, public BBinder
{
public:
    virtual sp<IInterface>      queryLocalInterface(const String16& _descriptor);
    virtual const String16&     getInterfaceDescriptor() const;

protected:
    virtual IBinder*            onAsBinder();
};
```

## IPCThreadState

frameworks/base/include/binder/IPCThreadState.h

```c++
class IPCThreadState
{
public:
    static  IPCThreadState*     self();
    
            sp<ProcessState>    process();
            
...

            void                joinThreadPool(bool isMain = true);
            
            // Stop the local process.
            void                stopProcess(bool immediate = true);
            
            status_t            transact(int32_t handle,
                                         uint32_t code, const Parcel& data,
                                         Parcel* reply, uint32_t flags);

...
    
private:
                                IPCThreadState();
                                ~IPCThreadState();

            status_t            sendReply(const Parcel& reply, uint32_t flags);
            status_t            waitForResponse(Parcel *reply,
                                                status_t *acquireResult=NULL);
            status_t            talkWithDriver(bool doReceive=true);
            status_t            writeTransactionData(int32_t cmd,
                                                     uint32_t binderFlags,
                                                     int32_t handle,
                                                     uint32_t code,
                                                     const Parcel& data,
                                                     status_t* statusBuffer);
            status_t            executeCommand(int32_t command);
            
...
};
```

