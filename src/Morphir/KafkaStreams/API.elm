module Morphir.KafkaStreams.API exposing (..)

import Morphir.Scala.AST as Scala


kStream: Scala.Type
kStream =
    Scala.TypeRef [ "org", "apache", "kafka", "streams", "scala", "kstream" ] "KStream[Null,String]"

streamFilter : Scala.Value -> Scala.Value -> Scala.Value
streamFilter lambda inputKStream =
    Scala.Apply
        (Scala.Select
            inputKStream
            "filter" -- Scala .filter() function
        )
        [ Scala.ArgValue Nothing lambda ]

