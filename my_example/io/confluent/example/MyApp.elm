module Io.Confluent.Example.MyApp exposing(..)

{-
request : Int -> Int -> Result String Int
request availability requestedQuantity =
    if requestedQuantity <= availability then
        Ok requestedQuantity
    else
        Err "Insufficient availability"
-}

{-

type alias RecordA =
    { number1 : Int
    , number2 : Int
    }

type alias RecordB =
    { sum : Int
    , product : Int
    , ratio : Float
    }


job : List RecordA -> List RecordB
job input =
    input
        |> List.filter (\a -> a.field2 < 100)
        |> List.map
            (\a ->
                { sum = a.number1 + a.number2
                , product = a.number1 * a.number2
                , ratio = a.number1 / a.number2
                }
            )
-}

example: List String -> List String
example kstream =
    kstream
        |> List.filter (\myValue -> True)

