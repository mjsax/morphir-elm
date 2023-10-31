import org.apache.kafka.common.serialization.{StringDeserializer, StringSerializer, VoidDeserializer, VoidSerializer}
import org.apache.kafka.streams.TopologyTestDriver
import org.apache.kafka.streams.scala.serialization
import org.junit.jupiter.api.Test

import scala.Predef.->
import scala.reflect.ClassManifestFactory.Null

class MorphirTest {
  import serialization.Serdes._

  @Test
  def shouldRunTopology(): Unit = {
    val topology = MorphirTopology.topology()

    val ttd = new TopologyTestDriver(topology)

    val input = ttd.createInputTopic("input-topic", new VoidSerializer, new StringSerializer)
    val result = ttd.createOutputTopic("result-topic", new VoidDeserializer, new StringDeserializer)

    input.pipeInput("keep-it")
    input.pipeInput("drop-it")
    input.pipeInput("keep-it")

    result.readValuesToList().iterator().forEachRemaining(
      v => System.out.println(v)
    )
  }
}
