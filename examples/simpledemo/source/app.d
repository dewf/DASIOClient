import std.stdio;
import core.thread;
import core.time;
import std.math;

import dasioclient;

private class Switcher : AsioDelegate {
	private AsioDevice dev;
	private float samplePeriod;
	private float curSample;
	override void deviceOpened(AsioDevice d) {
		this.dev = d;
		samplePeriod = d.currentSampleRate / 220.0;
		curSample = 0.0;
	}
	override void bufferSwitch(float[][] inputs, float[][] outputs) {
		for (int i; i< dev.props.bufferSampleLength; i++) {
			const phase = (curSample * 2.0 * PI) / samplePeriod;
			const value = sin(phase);
			for (int j; j< dev.props.numOutputs; j++) {
				outputs[j][i] = value;
			}
			curSample = fmod(curSample + 1.0, samplePeriod);
		}
	}
}

void main()
{
	auto all_devices = enumerateDevices();
	foreach (info; all_devices) {
		writefln("interface: %s (%s)", info.name, info.id);
	}

	auto dev = new AsioDevice(all_devices[0].id, new Switcher());

	if (dev.open()) {
		if (dev.start()) {
			writeln("sleeping 5 seconds...");
			Thread.sleep(5.seconds);
			dev.stop();
		}
		dev.close();
	}
}
