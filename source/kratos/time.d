module kratos.time;

import std.algorithm : min;

/*
struct Timer
{
	import vibe.data.serialization;
	import kgl3n.math;

	float endTime = 1, currentTime = 0;

	alias TickCallback = void delegate(ref Timer timer);
	@ignore
	TickCallback[] tickCallbacks;


	bool running = false;

	void update()
	{
		if(running)
		{
			currentTime = min(currentTime + Time.delta, endTime);
			running = currentTime < endTime;

			foreach(callback; tickCallbacks) callback(this);
		}
	}

	void start()
	{
		currentTime = 0;
		running = true;
	}

	void stop()
	{
		currentTime = 0;
		running = false;
	}

	@property
	{
		float phase() const
		{
			return currentTime / endTime;
		}

		float smoothPhase() const
		{
			return smoothStep(0, endTime, currentTime);
		}
	}
}
*/