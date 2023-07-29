# Connect to RabbitMQ
# Retrieve a job (message)
# Retrieve the image
# Start image processing
# Upload the image
# Acknowledge the message (and thus remove it from the queue)

require 'rubygems'
require 'bundler/setup'

# See https://github.com/ruby-amqp/bunny
# And:
# - https://www.rabbitmq.com/tutorials/tutorial-one-ruby.html
# - https://www.rabbitmq.com/tutorials/tutorial-two-ruby.html
require 'bunny'
require 'fog/aws'
require 'json'
require 'pry'

class ImargardWorkingHard

  def initialize
    @rabbit_host = ENV["RABBITMQ_HOST"] || "localhost"
    @object_store_host = ENV["OBJECT_STORE_HOST"] || "localhost"
    @object_store_access_key_id     = ENV['OBJECT_STORE_ACCESS_KEY_ID'] || 'AKIAIOSFODNN7EXAMPLE'
    @object_store_secret_access_key = ENV['OBJECT_STORE_SECRET_ACCESS_KEY'] || 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'
    
    @object_recognition_infile = "/tmp/object_recognition/original-image.jpg"    # TODO make configurable
    @object_recognition_outfile = "/tmp/object_recognition/filtered-image.jpg"   # TODO make configurable

    @rabbit_con = Bunny.new("amqp://guest:guest@#{@rabbit_host}:5672") #TODO make username, password, and port configurable
    @rabbit_con.start

    @rabbit_channel = @rabbit_con.create_channel
    @rabbit_queue = @rabbit_channel.queue("images", durable: true) # TODO make configurable

    @obj_store_con = connect_to_object_store
  end

  protected

  #TODO Make fog credentials configurable
  def connect_to_object_store
    # Fog AWS Gem. See: 
    #   https://github.com/fog/fog-aws
    #   https://www.rubydoc.info/github/fog/fog-aws
    # MinIO emulates the AWS API > use the AWS adapter
    connection = Fog::Storage.new({
      provider:              'AWS',                               # TODO make other providers configurable
      aws_access_key_id:     @object_store_access_key_id,
      aws_secret_access_key: @object_store_secret_access_key,
      region:                'us-east-1', # ,                     # optional, defaults to 'us-east-1',
                                                                  # Please mention other regions if you have changed
                                                                  # minio configuration
      host:                  @object_store_host,                  # Provide your host name here, otherwise fog-aws defaults to
                                                                  # s3.amazonaws.com
      endpoint:              "http://#{@object_store_host}:9000", # TODO make port configurable
      path_style:            true,                                # Required
  })
    return connection
  end

  def retrieve_object_recognition_infile_from_object_store(filepath)    
    puts "\t\tStarting to retrieve object #{filepath} and storing it to #{@object_recognition_infile}..."
    directory = @obj_store_con.directories.get('infiles') # TODO make configurable
    remote_file = directory.files.get(filepath)

    # Create local file from the remote file    
    File.open(@object_recognition_infile, "w") do |local_file|

      # Only recommendable for small objects
      local_file.write(remote_file.body)
    end  
    puts "\t\tDone."
  end

  def upload_object_recognition_outfile_to_object_store(object_name)    
    puts "\t\tStarting to upload object #{object_name} from local file #{@object_recognition_outfile}"
    @obj_store_con.put_object(
        'outfiles', # TODO make configurable
        object_name,

        # Only recommendable for small objects
        File.read(@object_recognition_outfile),
        content_type: "image/jpeg" # TODO make configurable
      )
  end

  def cleanup
    puts "\t\tRemoving local files #{@object_recognition_infile} and #{@object_recognition_outfile}"

    # Delete the old infile. This avoids accidentally processing a file twice.
    FileUtils.rm @object_recognition_infile
    FileUtils.rm @object_recognition_outfile

    puts "\t\tDone."
  end

  def execute_object_recognition
    cmd = 'python3 yolo_opencv.py --image /tmp/object_recognition/original-image.jpg --config yolov3.cfg --weights yolov3.weights --classes yolov3.txt'
    puts "\t\tExecuting object recognition with CMD: #{cmd}"
    system(cmd)
    puts "\t\tDone."
  end

  public

  def work!
    puts "Imrgard started working hard ..."
    # Manual acknowledgement gives us control over when the processing of the image was successful
    # Unsuccessful processing should leave the message in the queue for other workers to pick up.
    @rabbit_queue.subscribe(manual_ack: true, block: true) do |delivery_info, properties, body|
      puts "\tReceived message: #{body}.\nStarting to process..."

      # Parse JSON message
      msg = JSON.parse(body)
      object_name = msg["name"]

      # Store as @object_recognition_infile
      retrieve_object_recognition_infile_from_object_store(object_name)

      execute_object_recognition
      
      upload_object_recognition_outfile_to_object_store(object_name)

      cleanup

      @rabbit_channel.ack(delivery_info.delivery_tag)
      puts "\tDone processing."
    end
    puts "Irmgard worked hard. Now going to rest a bit ..."
  end
end




ImargardWorkingHard.new.work!