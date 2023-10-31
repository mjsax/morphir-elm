module Morphir.KafkaStreams.API exposing (..)

import Morphir.Scala.AST as Scala


kStream: Scala.Type
kStream =
    Scala.TypeRef [ "org", "apache", "kafka", "streams", "scala", "kstream" ] "KStream[Null,String]"


streamFilter : Scala.Value -> Scala.Value -> Scala.Value
streamFilter predicate from =
    Scala.Apply
        (Scala.Select
            from
            "filter" -- Scala .filter() function
        )
        [ Scala.ArgValue Nothing (Scala.Lambda [("k", Nothing), ("v", Nothing)] predicate)
        ]

