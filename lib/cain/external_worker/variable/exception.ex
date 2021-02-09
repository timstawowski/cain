defmodule Cain.Variable.InvalidXmlFormatError do
  defexception message: "Given xml is invalid"
end

defmodule Cain.Variable.InvalidDateFormatError do
  defexception message: "Only 'Calendar.ISO' supported for 'NaiveDateTime'"
end

defmodule Cain.Variable.InvalidNameError do
  defexception message: "Given name in variable set has to be an 'atom' or 'binary()'"
end
