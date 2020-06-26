module c_api.CASIOClient;

// The following ifdef block is the standard way of creating macros which make exporting 

extern (C):

// from a DLL simpler. All files within this DLL are compiled with the CASIOCLIENT_EXPORTS
// symbol defined on the command line. This symbol should not be defined on any project
// that uses this DLL. This way any other project whose source files include this file see 
// CASIOCLIENT_API functions as being imported from a DLL, whereas this DLL sees symbols
// defined with this macro as being exported.

struct _CASIO_DeviceID;
alias CASIO_DeviceID = _CASIO_DeviceID*; // device descriptor, unique handle to open a particular device
struct _CASIO_Device;
alias CASIO_Device = _CASIO_Device*; // actual opened device

enum CASIO_EventType
{
    Log = 0,
    BufferSwitch = 1,
    SampleRateChanged = 2
}

enum CASIO_TimeFlags
{
    NanoSecs = 1,
    Samples = 2,
    TCSamples = 4
}

struct CASIO_TimeStruct
{
    uint flags;
    ulong nanoSeconds;
    ulong samples;
    ulong tcSamples;
}

struct CASIO_Event
{
    CASIO_EventType eventType;
    bool handled;

    union
    {
        struct LogEvent
        {
            const(char)* message;
        }
        LogEvent logEvent;

        // use CASIO_DeviceProperties to interpret these (count + sample type)

        // CASIO_TimeFlags
        struct BufferSwitchEvent
        {
            void** inputs;
            void** outputs;

            CASIO_TimeStruct time;
        }
        BufferSwitchEvent bufferSwitchEvent;

        struct SampleRateChangedEvent
        {
            double newSampleRate;
        }
        SampleRateChangedEvent sampleRateChangedEvent;
    }
}

alias CASIO_EventCallback = int function (CASIO_Event* event, CASIO_Device device, void* userData);

int CASIO_Init (CASIO_EventCallback callback);
int CASIO_Shutdown ();

struct CASIO_DeviceInfo
{
    CASIO_DeviceID id;
    const(char)* name;
}

int CASIO_EnumerateDevices (CASIO_DeviceInfo** outInfo, int* outCount);

enum CASIO_SampleFormat
{
    Unknown = 0,
    Int32 = 1, // all little-endian
    Float32 = 2,
    Float64 = 3
}

struct CASIO_DeviceProperties
{
    const(char)* name;
    int numInputs;
    int numOutputs;
    int bufferSampleLength;
    int bufferByteLength;
    CASIO_SampleFormat sampleFormat;
}

int CASIO_OpenDevice (CASIO_DeviceID id, void* userData, CASIO_Device* outDevice);
int CASIO_CloseDevice (CASIO_Device device);

int CASIO_GetProperties (CASIO_Device device, CASIO_DeviceProperties* props, double* currentSampleRate);

int CASIO_Start (CASIO_Device device);
int CASIO_Stop (CASIO_Device device);

int CASIO_ShowControlPanel (CASIO_Device device);

