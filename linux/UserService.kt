package com.build110.api

import io.reactivex.Observable

interface UserService {


    @GET(Constant.PATH_LOGIN)
    fun login(
        @Query("account") account: String,
        @Query("loginPass") password: String
    ): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_PANDECT)
    fun pandect(@Query("token") token: String): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_QUERYPROJECTNUMINFO)
    fun queryprojectnuminfo(@Query("token") token: String): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_SUPERVISE)
    fun supervise(@Query("token") token: String): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_PROJECT)
    fun project(
        @Query("token") token: String,
        @Query("pageNumber") pageNumber: Int,
        @Query("pageSize") pageSize: Int,
        @Query("projectCode") projectCode: String,
        @Query("oid") oid: String
    ): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_PROJECT_DETAIL)
    fun projectDetail(
        @Query("token") token: String,
        @Query("projectOid") projectOid: String
    ): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_VIDOE_LIST)
    fun videos(
        @Query("token") token: String,
        @Query("pageNumber") pageNumber: Int,
        @Query("pageSize") pageSize: Int,
        @Query("projectCode") projectCode: String,
        @Query("oid") oid: String
    ): Observable<Response<Map<Any, Any?>>>


    @GET(Constant.PATH_LIVE_VIDOE_LIST)
    fun liveVideos(
        @Query("token") token: String,
        @Query("projectOid") projectOid: String
    ): Observable<Response<Map<Any, Any?>>>


    @GET(Constant.PATH_LIVE_VIDOE)
    fun live(
        @Query("token") token: String,
        @Query("videoOid") videoOid: String
    ): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_LIVEDG_VIDOE)
    fun liveDg(
        @Query("token") token: String,
        @Query("videoOid") videoOid: String
    ): Observable<Response<Map<Any, Any?>>>





    @GET(Constant.PATH_DUST_LIST)
    fun dustList(
        @Query("token") token: String,
        @Query("pageNumber") pageNumber: Int,
        @Query("pageSize") pageSize: Int,
        @Query("serialNumber") projectCode: String,
        @Query("onlineStatus") onlineStatus: String,
        @Query("alertStatus") alertStatus: String,
        @Query("projectOid") projectOid: String
    ): Observable<Response<Map<Any, Any?>>>



    @GET(Constant.PATH_SPRAY_LIST)
    fun sprayList(
        @Query("token") token: String,
        @Query("pageNumber") pageNumber: Int,
        @Query("pageSize") pageSize: Int,
        @Query("projectCode") projectCode: String = "",
        @Query("onlineStatus") onlineStatus: String,
        @Query("isIllegal") isIllegal: String = "",
        @Query("oid") oid: String
    ): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_SPRAY_DETAIl)
    fun sprayDetail(
        @Query("token") token: String,
        @Query("oid") oid: String,
        @Query("onlineStatus") onlineStatus: String
    ): Observable<Response<Map<Any, Any?>>>

//    @GET(Constant.PATH_SPRAY_TIME)
//    fun sprayController(
//        @Query("token") token: String,
//        @Query("serialNumber") onlineStatus: String,
//        @Query("time") time: Int,
//        @Query("equipmentType") equipmentType: String="8"
//    ): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_SPRAY_CONTROLLER)
    fun sprayController(
        @Query("token") token: String,
        @Query("serialNumber") onlineStatus: String,
        @Query("time") time: Int
    ): Observable<Response<Map<Any, Any?>>>



    @GET(Constant.PATH_DUST)
    fun dustList(
        @Query("token") token: String,
        @Query("serialNumber") serialNumber: String
    ): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_DUST_CHART)
    fun dustChartList(
        @Query("token") token: String,
        @Query("fieldName") fieldName: String,
        @Query("days") days: String,
        @Query("blackBoxOid") blackBoxOid: String
    ): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_TJ)
    fun tjHeader(
        @Query("token") token: String,
        @Query("projectOid") projectOid: String,
        @Query("isOnline") isOnline: String = ""
    ): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_TJ_WORKWEIGHT)
    fun tjWorkweight(
        @Query("token") token: String,
        @Query("serialNumber") serialNumber: String,
        @Query("times") times: String = "20"
    ): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_TJ_WEIGHTPERCENT)
    fun tjWeightpercent(
        @Query("token") token: String,
        @Query("serialNumber") serialNumber: String,
        @Query("times") times: String = "20"
    ): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_TJ_WORKCYCLE)
    fun tjWorkcycle(
        @Query("token") token: String,
        @Query("serialNumber") serialNumber: String,
        @Query("days") days: String
    ): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_TJ_WORKILLEGAL)
    fun tjWorkillegal(
        @Query("token") token: String,
        @Query("serialNumber") serialNumber: String,
        @Query("days") days: String
    ): Observable<Response<Map<Any, Any?>>>



    @GET(Constant.PATH_PASSWORD)
    fun password(
        @Query("token") token: String,
        @Query("oldPass") oldPass: String,
        @Query("loginPass") loginPass: String,
        @Query("loginPassTwo") loginPassTwo: String
    ): Observable<Response<Map<Any, Any?>>>


    @GET(Constant.PATH_TJ_ILLEGALDETAIL)
    fun tjillegaldetail(
        @Query("token") token: String,
        @Query("serialNumber") serialNumber: String,
        @Query("date") Date: String
    ): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_ELEVATOR_ILLEGALDETAIL)
    fun elevatorillegaldetail(
        @Query("token") token: String,
        @Query("serialNumber") serialNumber: String,
        @Query("date") Date: String
    ): Observable<Response<Map<Any, Any?>>>


    @GET(Constant.PATH_HISTORY)
    fun history(
        @Query("token") token: String,
        @Query("serialNumber") serialNumber: String,
        @Query("equipmentType") type: String
    ): Observable<Response<Map<Any, Any?>>>


    @GET(Constant.PATH_CAR_WASH)
    fun carWashList(
        @Query("token") token: String,
        @Query("pageNumber") pageNumber: Int,
        @Query("pageSize") pageSize: Int,
        @Query("oid") oid: String
    ): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_CAR_WASH_STATISTICS)
    fun carWashStatistics(
        @Query("token") token: String,
        @Query("serialNumber") serialNumber: String
    ): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_CAR_WASH_HISTORY)
    fun carWashHistory(
        @Query("token") token: String,
        @Query("serialNumber") serialNumber: String,
        @Query("date") date: String = "",
        @Query("pageNumber") pageNumber: Int = 1,
        @Query("pageSize") pageSize: Int = 10
    ): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_CAR_WASH_ALARM)
    fun carWashAlarm(
        @Query("token") token: String,
        @Query("serialNumber") serialNumber: String
    ): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_CAR_WASH_VIDEO)
    fun carWashVideo(
        @Query("token") token: String,
        @Query("serialNumber") serialNumber: String
    ): Observable<Response<Map<Any, Any?>>>

    @GET(Constant.PATH_CAR_WASH_RESULT)
    fun carWashResult(
        @Query("token") token: String,
        @Query("serialNumber") serialNumber: String
    ): Observable<Response<Map<Any, Any?>>>



    @GET(Constant.PATH_PERSONWORKTYPE)
    fun personWorkType(
        @Query("token") token: String,
        @Query("projectOid") serialNumber: String
    ): Observable<Response<Map<Any, Any?>>>


    @GET(Constant.PATH_ATTENDANCEBYWEEK)
    fun attendanceByWeek(
        @Query("token") token: String,
        @Query("projectOid") serialNumber: String
    ): Observable<Response<Map<Any, Any?>>>






}
