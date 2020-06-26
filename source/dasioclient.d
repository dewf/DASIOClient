import std.stdio;
import std.string;
import std.conv;
import c_api.CASIOClient;

import core.stdc.string; // for memset

struct AsioDeviceInfo {
    CASIO_DeviceID id;
    string name;
}

AsioDeviceInfo[] enumerateDevices() {
    CASIO_DeviceInfo *infos;
    int count;
    if (CASIO_EnumerateDevices(&infos, &count) != 0) {
        writeln("DASIOClient: some error enumerating devices");
    }

    AsioDeviceInfo[] ret;
    foreach (info; infos[0..count]) {
        AsioDeviceInfo adi = {info.id, to!string(info.name)};
        ret ~= adi;
    }

    return ret;
}

interface AsioDelegate {
    void deviceOpened(AsioDevice d);
    void bufferSwitch(float[][] inputs, float[][] outputs); // client processing override
}

class AsioDevice
{
    private CASIO_DeviceID id;
    private CASIO_Device handle;
    
    private AsioDelegate asioDelegate;
    private float[][] floatInputs;
    private float[][] floatOutputs;
    private bool started;

    CASIO_DeviceProperties _props;
    @property CASIO_DeviceProperties props() { return _props; }
    
    double _currentSampleRate;
    @property double currentSampleRate() { return _currentSampleRate; }
    @property void currentSampleRate(double value) { 
        _currentSampleRate = value; 
    }

    this(CASIO_DeviceID id, AsioDelegate asioDelegate)
    {
        this.id = id;
        this.asioDelegate = asioDelegate;
    }

    ~this()
    {
        close();
    }

    bool open()
    {
        if (CASIO_OpenDevice(id, cast(void*) this, &handle) != 0)
        {
            writeln("failed to open ASIO device");
            handle = null;
            return false;
        }
        CASIO_GetProperties(handle, &_props, &_currentSampleRate);

        // allocate internal buffers (float[] to make everything easy)
        floatInputs = new float[][](props.numInputs, props.bufferSampleLength);
        floatOutputs = new float[][](props.numOutputs, props.bufferSampleLength);

        asioDelegate.deviceOpened(this);

        return true;
    }

    void close()
    {
        if (handle)
        {
            if (started) stop();
            CASIO_CloseDevice(handle);
            handle = null;
        }
    }

    bool start() {
        if (handle) {
            if (CASIO_Start(handle) == 0) {
                started = true;
                return true;
            }
        }
        return false;
    }

    void stop() {
        if (handle && started) {
            CASIO_Stop(handle);
            started = false;
        }
    }

    private void bufferSwitchInt32(int **inputs, int **outputs, CASIO_TimeStruct time) {
        for (int i; i< props.numInputs; i++) {
            for (int j; j< props.bufferSampleLength; j++) {
                floatInputs[i][j] = inputs[i][j] / (1 << 30);
            }
        }

        asioDelegate.bufferSwitch(this.floatInputs, this.floatOutputs);

        for (int i; i< props.numOutputs; i++) {
            for (int j; j< props.bufferSampleLength; j++) {
                outputs[i][j] = cast(int)(floatOutputs[i][j] * (1 << 30));
            }
        }
    }

    private void bufferSwitchUnknown(void **outputs) {
        // just zero the buffers
        for (int i; i< props.numOutputs; i++) {
            memset(outputs[i], 0, props.bufferByteLength);
        }
    }
}

private extern (C) int asioCallback(CASIO_Event* event, CASIO_Device device, void* userData)
{
    auto asioDevice = cast(AsioDevice)userData; // might be null
    event.handled = true;
    switch (event.eventType)
    {
    case CASIO_EventType.Log:
        // asioDevice not necessarily valid here
        auto msg = to!string(event.logEvent.message);
        writefln("ASIO>> %s", msg);
        break;

    case CASIO_EventType.SampleRateChanged: 
    {
        asioDevice.currentSampleRate = event.sampleRateChangedEvent.newSampleRate;
        break;
    }

    case CASIO_EventType.BufferSwitch:
    {
        switch(asioDevice.props.sampleFormat) {
            case CASIO_SampleFormat.Int32:
                asioDevice.bufferSwitchInt32(cast(int **)event.bufferSwitchEvent.inputs, cast(int **)event.bufferSwitchEvent.outputs, event.bufferSwitchEvent.time);
                break;
            default:
                asioDevice.bufferSwitchUnknown(event.bufferSwitchEvent.outputs);
                break;
        }
        break;
    }

    default:
        event.handled = false;
    }
    return 0;
}

static this()
{
    CASIO_Init(&asioCallback);
}

static ~this()
{
    CASIO_Shutdown();
}
