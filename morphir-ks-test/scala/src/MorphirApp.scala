import java.time.Duration
import java.util.Properties

import org.apache.kafka.streams.kstream.Materialized
import org.apache.kafka.streams.scala.ImplicitConversions._
import org.apache.kafka.streams.scala._
import org.apache.kafka.streams.scala.kstream._
import org.apache.kafka.streams.{KafkaStreams, StreamsConfig}

object MorphirApp extends App {
  import serialization.Serdes._

  val props: Properties = {
    val p = new Properties()
    p.put(StreamsConfig.APPLICATION_ID_CONFIG, "morphir-app")
    p.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092")
    p
  }

  val topology = MorphirTopology.topology()

  val streams: KafkaStreams = new KafkaStreams(topology, props)
  streams.start()

  sys.ShutdownHookThread {
    streams.close(Duration.ofSeconds(10))
  }
}