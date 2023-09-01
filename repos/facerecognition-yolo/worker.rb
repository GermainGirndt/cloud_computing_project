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
    puts "--- Initializing Ruby worker..."
    @rabbit_host = ENV["RABBITMQ_HOST"] || "localhost"
    @rabbit_protocol = "amqp"
    @rabbit_user = ENV["RABBITMQ_DEFAULT_USER"] || "guest"
    @rabbit_password = ENV["RABBITMQ_DEFAULT_PASS"] || "guest"
    @rabbit_port = ENV["RABBITMQ_PORT"] || "5672"
    @rabbit_image_queue_name = ENV["RABBITMQ_IMAGE_QUEUE_NAME"] || "images"
    
    @object_store_host = ENV["OBJECT_STORE_HOST"] || "localhost"
    @object_store_port = ENV["OBJECT_STORE_PORT"] || "9000"
    @object_store_access_key_id     = ENV['OBJECT_STORE_ACCESS_KEY_ID'] || 'AKIAIOSFODNN7EXAMPLE'
    @object_store_secret_access_key = ENV['OBJECT_STORE_SECRET_ACCESS_KEY'] || 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'
    @object_store_original_images_bucket_name       = ENV['OBJECT_STORE_ORIGINAL_IMAGES_BUCKET_NAME'] || 'infiles'
    @object_store_blurred_images_bucket_name       = ENV['OBJECT_STORE_BLURRED_IMAGES_BUCKET_NAME'] || 'outfiles'
    @object_store_default_provider       = ENV['OBJECT_STORE_DEFAULT_PROVIDER'] || 'AWS'
    
    @object_recognition_infile = ENV['OBJECT_RECOGNITION_INFILE_PATH'] || "/tmp/object_recognition/original-image.jpg"
    @object_recognition_outfile = ENV['OBJECT_RECOGNITION_OUTFILE_PATH'] || "/tmp/object_recognition/filtered-image.jpg"
    @object_recognition_content_type_to_be_stored = ENV['OBJECT_RECOGNITION_CONTENT_TYPE_TO_BE_STORED'] || "image/jpeg"

    @rabbit_con = Bunny.new("#{@rabbit_protocol}://#{@rabbit_user}:#{@rabbit_password}@#{@rabbit_host}:#{@rabbit_port}")

    @rabbit_con.start

    @rabbit_channel = @rabbit_con.create_channel

    @rabbit_is_image_durable = string_to_bool(ENV['IS_MESSAGE_QUEUE_IMAGE_DURABLE'] || 'true')
    @rabbit_queue = @rabbit_channel.queue(@rabbit_image_queue_name, durable: @rabbit_is_image_durable) 

    @obj_store_con = connect_to_object_store
  end

  protected

  def connect_to_object_store
    # Fog AWS Gem. See: 
    #   https://github.com/fog/fog-aws
    #   https://www.rubydoc.info/github/fog/fog-aws
    # MinIO emulates the AWS API > use the AWS adapter
    connection = Fog::Storage.new({
      provider:              @object_store_default_provider,
      aws_access_key_id:     @object_store_access_key_id,
      aws_secret_access_key: @object_store_secret_access_key,
      region:                'us-east-1', # ,                     # optional, defaults to 'us-east-1',
                                                                  # Please mention other regions if you have changed
                                                                  # minio configuration
      host:                  @object_store_host,                  # Provide your host name here, otherwise fog-aws defaults to
                                                                  # s3.amazonaws.com
      endpoint:              "http://#{@object_store_host}:#{@object_store_port}",
      path_style:            true,                                # Required
  })
    return connection
  end

  def retrieve_object_recognition_infile_from_object_store(filepath)
    puts "\t\tStarting to retrieve object #{filepath} and storing it to #{@object_recognition_infile}..."
    directory = @obj_store_con.directories.get(@object_store_original_images_bucket_name)
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
        @object_store_blurred_images_bucket_name, 
        object_name,

        # Only recommendable for small objects
        File.read(@object_recognition_outfile),
        content_type: @object_recognition_content_type_to_be_stored 
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
  
  def string_to_bool(str)
    case str.downcase
    when "true" then true
    when "false" then false
    else
      # Handle other cases or raise an error
      raise ArgumentError, "Invalid string for boolean conversion: " + str
    end
  end
end




ImargardWorkingHard.new.work!