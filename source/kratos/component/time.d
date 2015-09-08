module kratos.component.time;

import core.time;
import std.algorithm.comparison : min;
import kratos.ecs.scene : SceneComponent;
import vibe.data.json : Json;

final class Time : SceneComponent
{
	private
	{
		TickDuration previousTick;
		
		real _total = 0;
		float _delta = 0;
	}

	float scale = 1;
	float maxDelta = .1f;

	void initialize()
	{
		previousTick = TickDuration.currSystemTick;
	}

	void reset()
	{
		previousTick = TickDuration.currSystemTick;
		_total = 0;
		_delta = 0;
	}

	//TODO: Make this a frameUpdate, and build the dependency graph thingy
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
	
	@property nothrow
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

	public static Time fromRepresentation(Json representation)
	{
		auto time = new Time();
		time._total = representation["total"].opt!double(0);
		time._delta = representation["delta"].opt!float(0);
		time.scale = representation["scale"].opt!float(1);
		time.maxDelta = representation["maxDelta"].opt!float(0.1f);
		return time;
	}

	public Json toRepresentation()
	{
		auto representation = Json.emptyObject;
		representation["total"] = _total;
		representation["delta"] = _delta; // Not sure if this should be serialized, but meh.
		representation["scale"] = scale;
		representation["maxDelta"] = maxDelta;
		return representation;
	}
}