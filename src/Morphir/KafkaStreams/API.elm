module Morphir.KafkaStreams.API exposing (..)

import Morphir.Scala.AST as Scala


kStream: Scala.Type -> Scala.Type
kStream valueType =
    let
        typeName : String
        typeName = 
            case valueType of
                Scala.TypeRef _ name -> name

                other ->
                    let
                      _= Debug.log "ERROR -- KafkaStremas (unknown type):" other
                    in
                    "unknown type"

    in
    Scala.TypeRef [ "org", "apache", "kafka", "streams", "scala", "kstream" ] ("KStream[Null," ++ typeName ++ "]")

streamFilter : Scala.Value -> Scala.Value -> Scala.Value
streamFilter lambda inputKStream =
    Scala.Apply
        (Scala.Select
            inputKStream
            "filter" -- Scala .filter() function
        )
        [ Scala.ArgValue Nothing lambda ]

field: Scala.Value -> String -> Scala.Value
field variable attribute =
    Scala.Select variable attribute
