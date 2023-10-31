module Morphir.KafkaStreams.AST exposing (Error, ObjectExpression(..), Expression(..), objectExpressionFromValue)



import Morphir.IR.Distribution as Distribution exposing (Distribution)
import Morphir.IR.Literal exposing (Literal(..))
import Morphir.IR.Name as Name exposing (Name)
import Morphir.IR.Value as Value exposing (Pattern(..), TypedValue)

import Morphir.SDK.ResultList as ResultList



type Error
    = UnhandledValue TypedValue
    | UnhandledExpression TypedValue

type alias ObjectName =
    Name

type ObjectExpression
    = From ObjectName
    | Filter Expression ObjectExpression

type Expression
    = Literal Literal
    | Lambda Name Expression -- we limit our lambda to a single input parameter (namly the Kafka Streams value) for now

objectExpressionFromValue : Distribution -> TypedValue -> Result Error ObjectExpression
objectExpressionFromValue ir morphirValue =
    case morphirValue of
        -- variable
        Value.Variable _ varName ->
            From varName |> Ok

        -- List.filter

        Value.Apply _ (Value.Apply _ (Value.Reference _ ( [ [ "morphir" ], [ "s", "d", "k" ] ], [ [ "list" ] ], [ "filter" ] )) predicate) sourceKStream ->
            objectExpressionFromValue ir sourceKStream
                |> Result.andThen
                    (\stream ->
                        expressionFromValue ir predicate
                            |> Result.map (\fieldExp -> Filter fieldExp stream)
                    )

        other ->
            let
                _ = Debug.log "CRASH -- KafkaStreams unhandled value: " other
            in
            Err (UnhandledValue other)

expressionFromValue : Distribution -> TypedValue -> Result Error Expression
expressionFromValue ir morphirValue =
    case morphirValue of
        Value.Literal _ literal ->
            Literal literal |> Ok

        Value.Lambda _ (Value.AsPattern _ (Value.WildcardPattern _) parameter) body ->
            expressionFromValue ir body
                |> Result.map (\expression -> Lambda parameter expression)

        other ->
            let
                _ = Debug.log "CRASH -- KafkaStreams unhandled expression: " other
            in
            Err (UnhandledExpression other)

