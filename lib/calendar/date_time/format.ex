defmodule Calendar.DateTime.Format do
  alias Calendar.DateTime
  alias Calendar.Strftime
  alias Calendar.ContainsDateTime
  @secs_between_year_0_and_unix_epoch 719528*24*3600 # From erlang calendar docs: there are 719528 days between Jan 1, 0 and Jan 1, 1970. Does not include leap seconds

  @doc """
  Deprecated in this module: The function has instead been moved to the `Calendar.Strftime` module.
  """
  def strftime!(dt, string, lang\\:en) do
    dt = dt |> contained_date_time
    IO.puts :stderr, "Warning: strftime!/1 in Calendar.DateTime.Format is deprecated." <>
                     "The function has been moved so use Calendar.Strftime.strftime! instead. " <>
                     Exception.format_stacktrace()
    Strftime.strftime!(dt, string, lang)
  end

  @doc """
  Format a DateTime as an RFC 2822 timestamp.

  ## Examples
      iex> Calendar.DateTime.from_erl!({{2010, 3, 13}, {11, 23, 03}}, "America/Los_Angeles") |> rfc2822
      "Sat, 13 Mar 2010 11:23:03 -0800"
      iex> Calendar.DateTime.from_erl!({{2010, 3, 13}, {11, 23, 03}}, "Etc/UTC") |> rfc2822
      "Sat, 13 Mar 2010 11:23:03 +0000"
  """
  def rfc2822(dt) do
    dt = dt |> contained_date_time
    Strftime.strftime! dt, "%a, %d %b %Y %T %z"
  end

  @doc """
  Format a DateTime as an RFC 822 timestamp.

  Note that this format is old and uses only 2 digits to denote the year!

  ## Examples
      iex> Calendar.DateTime.from_erl!({{2010, 3, 13}, {11, 23, 03}}, "America/Los_Angeles") |> rfc822
      "Sat, 13 Mar 10 11:23:03 -0800"
      iex> Calendar.DateTime.from_erl!({{2010, 3, 13}, {11, 23, 03}}, "Etc/UTC") |> rfc822
      "Sat, 13 Mar 10 11:23:03 +0000"
  """
  def rfc822(dt) do
    dt = dt |> contained_date_time
    Strftime.strftime! dt, "%a, %d %b %y %T %z"
  end

  @doc """
  Format a DateTime as an RFC 850 timestamp.

  Note that this format is old and uses only 2 digits to denote the year!

  ## Examples
      iex> Calendar.DateTime.from_erl!({{2010, 3, 13}, {11, 23, 03}}, "America/Los_Angeles") |> rfc850
      "Sat, 13-Mar-10 11:23:03 PST"
  """
  def rfc850(dt) do
    dt = dt |> contained_date_time
    Strftime.strftime! dt, "%a, %d-%b-%y %T %Z"
  end

  @doc """
  Format as ISO 8601 Basic

  # Examples

      iex> Calendar.DateTime.from_erl!({{2014, 9, 26}, {20, 10, 20}}, "Etc/UTC",5) |> Calendar.DateTime.Format.iso_8601_basic
      "20140926T201020Z"
      iex> Calendar.DateTime.from_erl!({{2014, 9, 26}, {17, 10, 20}}, "America/Montevideo",5) |> Calendar.DateTime.Format.iso_8601_basic
      "20140926T171020-0300"
  """
  def iso_8601_basic(dt) do
    dt = dt |> contained_date_time
    offset_part = rfc3339_offset_part(dt, dt.timezone)
    |> String.replace(":", "")
    Strftime.strftime!(dt, "%Y%m%dT%H%M%S")<>offset_part
  end

  @doc """
  Takes a DateTime.
  Returns a string with the time in RFC3339 (a profile of ISO 8601)

  ## Examples

  Without microseconds

      iex> Calendar.DateTime.from_erl!({{2014, 9, 26}, {17, 10, 20}}, "America/Montevideo") |> Calendar.DateTime.Format.rfc3339
      "2014-09-26T17:10:20-03:00"

  With microseconds

      iex> Calendar.DateTime.from_erl!({{2014, 9, 26}, {17, 10, 20, 5}}, "America/Montevideo") |> Calendar.DateTime.Format.rfc3339
      "2014-09-26T17:10:20.000005-03:00"
  """
  def rfc3339(%Calendar.DateTime{} = dt) do
    Strftime.strftime!(dt, "%Y-%m-%dT%H:%M:%S")<>
    rfc3330_usec_part(dt.usec, 6)<>
    rfc3339_offset_part(dt, dt.timezone)
  end
  def rfc3339(dt), do: dt |> contained_date_time |> rfc3339

  defp rfc3339_offset_part(_, time_zone) when time_zone == "UTC" or time_zone == "Etc/UTC", do: "Z"
  defp rfc3339_offset_part(dt, _) do
    Strftime.strftime!(dt, "%z")
    total_off = dt.utc_off + dt.std_off
    sign = sign_for_offset(total_off)
    offset_amount_string = total_off |> secs_to_hours_mins_string
    sign<>offset_amount_string
  end
  defp sign_for_offset(offset) when offset < 0, do: "-"
  defp sign_for_offset(_), do: "+"
  defp secs_to_hours_mins_string(secs) do
    secs = abs(secs)
    hours = secs/3600.0 |> Float.floor |> trunc
    mins = rem(secs, 3600)/60.0 |> Float.floor |> trunc
    "#{hours|>pad(2)}:#{mins|>pad(2)}"
  end

  defp rfc3330_usec_part(nil, _), do: ""
  defp rfc3330_usec_part(_, 0), do: ""
  defp rfc3330_usec_part(usec, 6) do
    ".#{usec |> pad(6)}"
  end
  defp rfc3330_usec_part(usec, precision) when precision >= 1 and precision <=6 do
    ".#{usec |> pad(6)}" |> String.slice 0..precision
  end
  defp pad(subject, len, char\\?0) do
    String.rjust("#{subject}", len, char)
  end

  @doc """
  Takes a DateTime and a integer for number of decimals.
  Returns a string with the time in RFC3339 (a profile of ISO 8601)

  The decimal_count integer defines the number fractional second digits.
  The decimal_count must be between 0 and 6.

  Fractional seconds are not rounded up, but rather trucated.

  ## Examples

  DateTime does not have microseconds, but 3 digits of fractional seconds
  requested. We assume 0 microseconds and display three zeroes.

      iex> Calendar.DateTime.from_erl!({{2014, 9, 26}, {17, 10, 20}}, "America/Montevideo") |> Calendar.DateTime.Format.rfc3339(3)
      "2014-09-26T17:10:20.000-03:00"

  DateTime has microseconds and decimal count set to 6

      iex> Calendar.DateTime.from_erl!({{2014, 9, 26}, {17, 10, 20}}, "America/Montevideo",5) |> Calendar.DateTime.Format.rfc3339(6)
      "2014-09-26T17:10:20.000005-03:00"

  DateTime has microseconds and decimal count set to 5

      iex> Calendar.DateTime.from_erl!({{2014, 9, 26}, {17, 10, 20}}, "America/Montevideo",5) |> Calendar.DateTime.Format.rfc3339(5)
      "2014-09-26T17:10:20.00000-03:00"

  DateTime has microseconds and decimal count set to 0

      iex> Calendar.DateTime.from_erl!({{2014, 9, 26}, {17, 10, 20}}, "America/Montevideo",5) |> Calendar.DateTime.Format.rfc3339(0)
      "2014-09-26T17:10:20-03:00"
  """
  def rfc3339(%Calendar.DateTime{usec: nil} = dt, decimal_count) do
    # if the provided DateTime does not have usec defined, we set it to 0
    rfc3339(%{dt | usec: 0}, decimal_count)
  end
  def rfc3339(%Calendar.DateTime{} = dt, decimal_count) when decimal_count >= 0 and decimal_count <=6 do
    Strftime.strftime!(dt, "%Y-%m-%dT%H:%M:%S")<>
    rfc3330_usec_part(dt.usec, decimal_count)<>
    rfc3339_offset_part(dt, dt.timezone)
  end
  def rfc3339(dt, decimal_count) do
    dt |> contained_date_time |> rfc3339(decimal_count)
  end

  @doc """
  Takes a DateTime.
  Returns a string with the date-time in RFC 2616 format. This format is used in
  the HTTP protocol. Note that the date-time will always be "shifted" to UTC.

  ## Example

      # The time is 6:09 in the morning in Montevideo, but 9:09 GMT/UTC.
      iex> DateTime.from_erl!({{2014, 9, 6}, {6, 9, 8}}, "America/Montevideo") |> DateTime.Format.httpdate
      "Sat, 06 Sep 2014 09:09:08 GMT"
  """
  def httpdate(dt) do
    dt = dt |> contained_date_time
    dt
    |> DateTime.shift_zone!("UTC")
    |> Strftime.strftime!("%a, %d %b %Y %H:%M:%S GMT")
  end

  @doc """
  Unix time. Unix time is defined as seconds since 1970-01-01 00:00:00 UTC without leap seconds.

  ## Examples

      iex> DateTime.from_erl!({{2001,09,09},{03,46,40}}, "Europe/Copenhagen", 55) |> DateTime.Format.unix
      1_000_000_000
  """
  def unix(date_time) do
    date_time = date_time |> contained_date_time
    date_time
    |> DateTime.shift_zone!("UTC")
    |> DateTime.gregorian_seconds
    |> - @secs_between_year_0_and_unix_epoch
  end

  @doc """
  Like unix_time but returns a float with fractional seconds. If the usec of the DateTime
  is nil, the fractional seconds will be treated as 0.0 as seen in the second example below:

  ## Examples

      iex> DateTime.from_erl!({{2001,09,09},{03,46,40}}, "Europe/Copenhagen", 985085) |> DateTime.Format.unix_micro
      1_000_000_000.985085

      iex> DateTime.from_erl!({{2001,09,09},{03,46,40}}, "Europe/Copenhagen") |> DateTime.Format.unix_micro
      1_000_000_000.0
  """
  def unix_micro(%Calendar.DateTime{usec: usec} = date_time) when usec == nil do
    date_time |> unix |> + 0.0
  end
  def unix_micro(%Calendar.DateTime{} = date_time) do
    date_time
    |> unix
    |> + (date_time.usec/1_000_000)
  end
  def unix_micro(date_time) do
    date_time |> contained_date_time |> unix_micro
  end

  @doc """
  Takes datetime and returns UTC timestamp in JavaScript format. That is milliseconds since 1970 unix epoch.

  ## Examples

      iex> DateTime.from_erl!({{2001,09,09},{03,46,40}}, "Europe/Copenhagen", 985085) |> DateTime.Format.js_ms
      1_000_000_000_985

      iex> DateTime.from_erl!({{2001,09,09},{03,46,40}}, "Europe/Copenhagen", 98508) |> DateTime.Format.js_ms
      1_000_000_000_098
  """
  def js_ms(date_time) do
    date_time = date_time |> contained_date_time
    whole_secs = date_time
    |> unix
    |> Kernel.* 1000
    whole_secs + micro_to_mil(date_time.usec)
  end

  defp micro_to_mil(usec) do
    "#{usec}"
     |> String.rjust(6, ?0) # pad with zeros if necessary
     |> String.slice(0..2)  # take first 3 numbers to get milliseconds
     |> Integer.parse
     |> elem(0) # return the integer part
  end

  defp contained_date_time(dt_container) do
    ContainsDateTime.dt_struct(dt_container)
  end
end
