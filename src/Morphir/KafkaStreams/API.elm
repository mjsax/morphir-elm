module Morphir.KafkaStreams.API exposing (..)

import Morphir.Scala.AST as Scala


kStream: Scala.Type
kStream =
    Scala.TypeRef [ "org", "apache", "kafka", "streams", "scala", "kstream" ] "KStream"
