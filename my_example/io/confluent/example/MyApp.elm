module Io.Confluent.Example.MyApp exposing(..)

{-
request : Int -> Int -> Result String Int
request availability requestedQuantity =
    if requestedQuantity <= availability then
        Ok requestedQuantity
    else
        Err "Insufficient availability"
-}

type alias MyRecord =
    { number1 : Int
    , number2 : Int
    }

{-
type alias RecordB =
    { sum : Int
    , product : Int
    , ratio : Float
    }


job : List RecordA -> List RecordB
job input =
    input
        |> List.filter (\a -> a.number1 < 100)
        |> List.map
            (\a ->
                { sum = a.number1 + a.number2
                , product = a.number1 * a.number2
                , ratio = a.number1 / a.number2
                }
            )
-}


exampleS: List String -> List String
exampleS kstream =
    kstream
        |> List.filter (\myValue -> myValue == "keep-it")



exampleR: List MyRecord-> List MyRecord
exampleR kstream =
    kstream
        |> List.filter (\myValue -> myValue.number1 < 100)
