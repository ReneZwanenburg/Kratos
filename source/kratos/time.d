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
