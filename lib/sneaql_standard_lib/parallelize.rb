require 'thread'

# used to run concurrent sneaql transforms
# from a threadsafe queue.
class ParallelizeSneaqlTransforms
  # initialize object and run concurrent transforms.
  # @param [Queue] queue_to_process queue of hashes with all params needed for transform
  # @param [Fixnum] concurrency number of threads
  # @param [Logger] logger optional logger object
  def initialize(queue_to_process, concurrency, logger = nil)
    @logger = logger ? logger : Logger.new(STDOUT)
    @queue_to_process = queue_to_process
    @concurrency = concurrency
    parallelize
  end

  # performs the actual parallel execution
  def parallelize
    @logger.info(
      "processing #{@queue_to_process} with a concurrency of #{@concurrency}..."
    )

    threads = []
    @concurrency.times do
      threads << Thread.new do
        # loop until there are no more things to do
        until @queue_to_process.empty?
          begin
            object_to_process = @queue_to_process.pop(true) rescue nil
            # logger.debug(object_to_process)
            t = Sneaql::Transform.new(
              object_to_process,
              @logger
            )
            t.run
          rescue => e
            @logger.error(e.message)
            e.backtrace.each { |b| @logger.error(b) }
          ensure
            @logger.info("finished processing #{object_to_process['transform_name']}")
          end
        end
      end
    end
    threads.each { |t| t.join }
    threads = nil
  end
end
