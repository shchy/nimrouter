import
    times
import
    ../../../src/alpaka

type
    
    User*   = object
        id*       : string
        name*     : string
        password* : string
    Tag*    = string
    TaskItem*   = object
        id*     : int
        name*   : string
        value*  : float
        tags*   : seq[Tag]
    Range*[T]   = object
        min*    : T
        max*    : T
    Sprint*     = object
        id*     : int
        name*   : string
        tasks*  : seq[TaskItem]
        scope*  : Range[Time]
    Project*    = object
        id*     : int
        name*   : string
        sprints*: seq[Sprint]
        users*  : seq[User]
    TaskAssign* = object
        taskID* : int
        userID* : int
    WorkUnit*   = object
        id*     : int
        name*   : string
        projectID*  : int
        scope*      : Range[Time]
    TaskRecord*     = object
        taskID*     : int
        value*      : float
        date*       : Time
        user*       : User
    WorkRecord*     = object
        user*       : User
        value*      : float
        date*       : Time
    
    
