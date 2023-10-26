module Morphir.KafkaStreams.AST exposing (Error, ObjectExpression(..), objectExpressionFromValue)



import Morphir.IR.Distribution as Distribution exposing (Distribution)
import Morphir.IR.Name as Name exposing (Name)
import Morphir.IR.Value as Value exposing (TypedValue)

import Morphir.SDK.ResultList as ResultList



type Error
    = UnhandledValue TypedValue

type alias ObjectName =
    Name

type ObjectExpression
    = From ObjectName



objectExpressionFromValue : Distribution -> TypedValue -> Result Error ObjectExpression
objectExpressionFromValue ir morphirValue =
    case morphirValue of
        Value.Variable _ varName ->
            From varName |> Ok

        other ->
            let
                _ = Debug.log "CRASH -- KafkaStreams unhandled value: " other
            in
            Err (UnhandledValue other)
