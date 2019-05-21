defmodule Opencensus.Absinthe.MiddlewareTest do
  use ExUnit.Case
  alias Opencensus.Absinthe.Middleware

  defmodule UnexpectedSpanishInquisition do
    defstruct []
  end

  describe "repr/1" do
    test "boolean" do
      assert true |> Middleware.repr() == "true"
    end

    test "nil" do
      assert nil |> Middleware.repr() == nil
    end

    test "Module name" do
      assert Middleware.repr(Elixir.Opencensus) == "Opencensus"
    end

    test "Absinthe list of string" do
      assert Middleware.repr(%Absinthe.Type.List{of_type: :string}) == "string[]"
    end

    test "Absinthe not-nullable string" do
      assert Middleware.repr(%Absinthe.Type.NonNull{of_type: :string}) == "string!"
    end

    test "struct" do
      assert Middleware.repr(%UnexpectedSpanishInquisition{}) ==
               "Opencensus.Absinthe.MiddlewareTest.UnexpectedSpanishInquisition"
    end

    test "Field" do
      field = %Absinthe.Type.Field{
        name: "hello",
        type: %Absinthe.Type.List{of_type: :string},
        __reference__: %{
          module: __MODULE__,
          location: %{
            file: "foo.ex",
            line: 23
          }
        }
      }

      assert Middleware.repr(field) == "Opencensus.Absinthe.MiddlewareTest:hello"
    end
  end
end
