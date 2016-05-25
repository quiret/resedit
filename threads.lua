local threads = createClass();

function createThread(start)
	local thread, env = createClass();
	local startTime = 0;
	local susTime = 0;
	local corot = coroutine.create(start);
	
	function thread.sustime(ns)
		susTime = ns;
		return true;
	end
	
	function thread.resume()
		if (isrunning()) then return end;
	
		startTime = getTickCount();
	
		coroutine.resume(corot);
		
		if (coroutine.status(corot) == "dead") then
			destroy();
		end
	end
	
	function thread.isrunning()
		return (coroutine.running() == corot);
	end
	
	function thread.yield()
		if not (isrunning()) then return end;
		
		if (getTickCount() - startTime < susTime) then return end;
		
		coroutine.yield();
	end
	
	function thread.destroy()
		corot = nil;
	end
	
	setfenv(start, env);
	
	thread.setParent(threads);
	return thread;
end

function threads_pulse()
	local m,n;
	
	threads.reference();
	
	for m,n in ipairs(threads.children) do
		n.resume();
	end
	
	threads.dereference();
	return true;
end

createThread(function()
		while (true) do
			collectgarbage("step");
			
			yield();
		end
	end, 50, 0
).sustime(5);