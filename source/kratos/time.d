module kratos.time;

import core.time;
import std.algorithm : min;

final abstract class Time
{
	static:

	private
	{
		TickDuration previousTick;
		
		real _total;
		float _delta;
	}

	public
	{
		float scale = 1;
		float maxDelta = .1f;
	}

	package
	{
		void reset()
		{
			previousTick = TickDuration.currSystemTick;
			_total = 0;
			_delta = 0;
		}

		void update()
		{
			auto currentTick = TickDuration.currSystemTick;
			
			auto delta = (currentTick - previousTick).to!("seconds", real);
			delta = min(delta, maxDelta);
			delta *= scale;

			_total += delta;
			_delta = delta;
			previousTick = currentTick;
		}
	}

	public @property nothrow
	{
		auto total() 
		{
			return _total;
		}

		auto delta()
		{
			return _delta;
		}
	}
}

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