module Morphir.KafkaStreams.Backend exposing (..)

import Dict exposing (Dict)
import Morphir.File.FileMap exposing (FileMap)
import Morphir.IR.Distribution as Distribution exposing (Distribution)


type alias Options =
    {}

mapDistribution : Options -> Distribution -> FileMap
mapDistribution _ distro =
        Dict.singleton (["io", "confluent", "example", "app", "myapp"], "KafkaStreamsTopology.java") "bar"
