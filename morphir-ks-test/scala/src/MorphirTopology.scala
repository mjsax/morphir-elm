import io.confluent.example.MyApp.exampleS
import org.apache.kafka.streams.scala.ImplicitConversions._
import org.apache.kafka.streams.Topology
import org.apache.kafka.streams.scala.{StreamsBuilder, serialization}
import org.apache.kafka.streams.scala.kstream.KStream

object MorphirTopology {

  def topology(): Topology = {
    import serialization.Serdes._

    val builder: StreamsBuilder = new StreamsBuilder
    val input: KStream[Null, String] = builder.stream[Null, String]("input-topic")

    val output = exampleS(input)

    output.to("result-topic")

    builder.build
  }
}
