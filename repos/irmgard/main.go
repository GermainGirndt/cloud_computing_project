// webservice
// image upload
// pg dependency
// rabbitmq

package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"log"
	"os"

	"github.com/go-pg/pg"
	"github.com/go-pg/pg/orm"
	"github.com/kataras/iris"
	"github.com/kataras/iris/middleware/logger"
	"github.com/kataras/iris/middleware/recover"
	"github.com/minio/minio-go"
	"github.com/streadway/amqp"
)

func main() {

	// Database
	postgresUsername := os.Getenv("POSTGRES_USERNAME")
	postgresPassword := os.Getenv("POSTGRES_PASSWORD")
	postgresHost := os.Getenv("POSTGRES_HOST")
	postgresPort := os.Getenv("POSTGRES_PORT")
	postgresDBName := os.Getenv("POSTGRES_DATABASE_NAME")
	
	db := pg.Connect(&pg.Options{
		Addr:     postgresHost + ":" + postgresPort,
		User:     postgresUsername,
		Password: postgresPassword,
		Database: postgresDBName,
	})
	defer db.Close()
	
	err := createSchema(db)
	if err != nil {
		panic(err)
	}
	
	// MinIO Object store
	minioHost := os.Getenv("MINIO_HOST")
	minioPort := os.Getenv("MINIO_PORT")
	
	minioEndpoint := minioHost + ":" + minioPort
	minioAccessKeyID := os.Getenv("MINIO_ACCESS_KEY")
	minioSecretAccessKey := os.Getenv("MINIO_SECRET_KEY")
	minioUseSSL := false

	// MinIO Make a new bucket called "images".
	bucketName := os.Getenv("MINIO_ORIGINAL_IMAGES_BUCKET_NAME") 
	location := "us-east-1" // Leave this to "us-east-1"

	// Initialize minio client object.
	minioClient, err := minio.New(minioEndpoint, minioAccessKeyID, minioSecretAccessKey, minioUseSSL)

	if err != nil {
		log.Fatalln(err)
	}

	// Make minIO bucket if not exists
	err = minioClient.MakeBucket(bucketName, location)
	if err != nil {

		// Check if the bucket already exists (which happens if you run this twice)
		exists, errBucketExists := minioClient.BucketExists(bucketName)

		if errBucketExists == nil && exists {
			log.Printf("MinIO: The bucket %s already exists \n", bucketName)
		} else {
			log.Fatalln(err)
		}

	} else {
		log.Printf("MinIO: Successfully created the bucket %s\n", bucketName)
	}

	// RabbitMQ
	const rabbitmqttProtocol = "amqp"
	rabbitmqUsername := os.Getenv("RABBITMQ_DEFAULT_USER")
	rabbitmqPassword := os.Getenv("RABBITMQ_DEFAULT_PASS")
	rabbitmqHost := os.Getenv("RABBITMQ_HOST")
	rabbitmqPort := os.Getenv("RABBITMQ_PORT")
	rabbitmqEndpoint := rabbitmqttProtocol + "://" + rabbitmqUsername + ":" + rabbitmqPassword + "@" + rabbitmqHost + ":" + rabbitmqPort + "/"
	rabbitmqImageQueueName := os.Getenv("RABBITMQ_IMAGE_QUEUE_NAME")

	conn, err := amqp.Dial(rabbitmqEndpoint)
	failOnError(err, "Failed to connect to RabbitMQ")
	defer conn.Close()

	// RabbitMQ - Channel
	ch, err := conn.Channel()
	failOnError(err, "Failed to open a channel")
	defer ch.Close()

	// RabbitMQ - Queue
	q, err := ch.QueueDeclare(
		rabbitmqImageQueueName, // name
		true,     // durable
		false,    // delete when unused
		false,    // exclusive
		false,    // no-wait
		nil,      // arguments
	)
	failOnError(err, "Failed to declare a queue")

	// Web Service
	app := iris.New()
	app.Logger().SetLevel("debug")

	// Recover panics
	app.Use(recover.New())
	app.Use(logger.New())

	// Method: GET
	// Resource http://localhost:8080
	app.Handle("GET", "/", func(ctx iris.Context) {
		var images []Image
		err := db.Model(&images).Order("id ASC").Select()

		if err != nil {
			panic(err)
		}

		if images == nil {
			images = []Image{}
		}

		ctx.JSON(images)
	})

	app.Handle("POST", "/", func(ctx iris.Context) {
		var image Image

		// Receive the incoming file
		// See also: https://github.com/kataras/iris/blob/c4843a4d82aae53518bb7c247923007d1d99893c/_examples/file-server/upload-file/main.go
		file, info, err := ctx.FormFile("image")

		if err != nil {
			ctx.StatusCode(iris.StatusInternalServerError)
			ctx.HTML("Fileupload: Error while uploading: " + err.Error() + "\n" + info.Filename)
			return
		}

		defer file.Close()

		// Upload the zip file to MinIO
		objectName := info.Filename
		fileName := info.Filename

		objectSize := info.Size
		objectReader := bufio.NewReader(file)

		fmt.Printf("Fileupload: Receiving file with path: " + fileName + "\n")

		// Upload the zip file with FPutObject
		n, err := minioClient.PutObject(bucketName, objectName, objectReader, objectSize, minio.PutObjectOptions{})
		if err != nil {
			log.Fatalln("Following fatal error was thrown:")
			log.Fatalln(err)
		}

		log.Printf("MinIO: Successfully uploaded %s of size %d\n", objectName, n)

		image.Name = fileName
		image.StorageLocation = bucketName + "/" + fileName

		// Write to the DB
		err = db.Insert(&image)
		if err != nil {
			ctx.Writef("PG database error: " + err.Error())
			return
		}

		body, err := json.Marshal(image)
		if (err) != nil {
			panic(err)
		}

		// Write to the message queue
		err = ch.Publish(
			"",     // exchange
			q.Name, // routing key
			false,  // mandatory
			false,
			amqp.Publishing{
				DeliveryMode: amqp.Persistent,
				ContentType:  "application/json",
				Body:         []byte(body),
			},
		)

		ctx.Writef("Success: %s %s", image.Name, image.StorageLocation)
	})

	app.Run(iris.Addr(":8080"), iris.WithoutServerError(iris.ErrServerClosed))
}

func getIndex(ctx iris.Context) {

}

// Image represents an image.
type Image struct {
	Id              int64  `json:"id"`
	Name            string `json:"name"`
	StorageLocation string `json:"storage_location"`
}

func (i *Image) String() string {
	return fmt.Sprintf("Image<%d %s %s>", i.Id, i.Name, i.StorageLocation)
}

func createSchema(db *pg.DB) error {
	models := []interface{}{
		(*Image)(nil),
	}

	for _, model := range models {
		err := db.CreateTable(model, &orm.CreateTableOptions{IfNotExists: true})
		if err != nil {
			return err
		}
	}

	return nil
}

func failOnError(err error, msg string) {
	if err != nil {
		log.Fatalf("%s: %s", msg, err)
	}
}