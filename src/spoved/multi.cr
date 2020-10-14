module Spoved::Multi(T)
  WORKERS = 4
  private property _jobs_channel = Channel(NamedTuple(id: Int32, data: T)).new
  private property _queued = 0
  private property _complete = 0
  private property _last_print_time = Time.monotonic
  private property _done_channel = Channel(Nil).new

  private def spawn_workers(prefix = "", quantity = WORKERS)
    quantity.times do |i|
      name = "#{prefix}JobFiber-#{i}"
      logger.trace { "[#{Fiber.current.name}] Spawning worker: #{name}" }
      spawn _start_worker(name)
    end
  end

  private def running? : Bool
    self._complete < self._queued || self._queued == 0
  end

  private def _start_worker(name)
    Fiber.current.name = name
    loop do
      logger.debug { "[#{Fiber.current.name}] Waiting for job" }
      _job = _jobs_channel.receive
      next if _job.nil?
      logger.trace { "[#{Fiber.current.name}][START][#{_job[:id]}] Received job #{_job[:id]}" }
      begin
        process(_job[:data])
      rescue ex
        logger.error(exception: ex) { "[#{Fiber.current.name}] #{ex.message}" }
      ensure
        _done_channel.send(nil)
      end
      logger.trace { "[#{Fiber.current.name}][DONE][#{_job[:id]}] Job complete" }
    end
  end

  private def queue_items(items : Indexable(T), fiber_name = "QueueFiber")
    self._queued = items.size
    spawn _queue_items(items, fiber_name)
  end

  private def _queue_items(items : Indexable(T), fiber_name)
    Fiber.current.name = fiber_name
    logger.info { "[#{Fiber.current.name}] Found #{items.size} items to queue" }

    _count = 0
    items.each do |_job|
      _count += 1
      _jobs_channel.send({
        id:   _count,
        data: _job,
      })
      logger.trace { "[#{Fiber.current.name}] Sent job #{_count}" }
    end
  end

  private def _print_job_status
    time = Time.monotonic
    if ((time - self._last_print_time).seconds >= 5)
      logger.info { "[#{Fiber.current.name}][Running] Jobs complete #{self._complete}/#{self._queued}" }
      self._last_print_time = time
    end
  end

  private def wait_till_done
    self._last_print_time = Time.monotonic
    while running?
      _print_job_status
      _done_channel.receive
      self._complete += 1
    end

    logger.info { "[#{Fiber.current.name}][DONE] Jobs complete #{self._complete}/#{self._queued}" }
  end

  abstract def process(job : T)
  abstract def logger
end
