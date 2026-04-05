///|
const HTTP_SECONDS_PER_DAY : Int64 = 86_400L

///|
fn zero_pad_2(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn floor_div_i64(lhs : Int64, rhs : Int64) -> Int64 {
  let quotient = lhs / rhs
  let remainder = lhs % rhs
  if remainder < 0L {
    quotient - 1L
  } else {
    quotient
  }
}

///|
fn positive_mod_i64(lhs : Int64, rhs : Int64) -> Int64 {
  let remainder = lhs % rhs
  if remainder < 0L {
    remainder + rhs
  } else {
    remainder
  }
}

///|
pub fn civil_from_days(days_since_epoch : Int64) -> (Int, Int, Int) {
  let z = days_since_epoch + 719_468L
  let era = if z >= 0L { z / 146_097L } else { (z - 146_096L) / 146_097L }
  let doe = z - era * 146_097L
  let yoe = (doe - doe / 1_460L + doe / 36_524L - doe / 146_096L) / 365L
  let year_base = yoe + era * 400L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let month_prime = (5L * doy + 2L) / 153L
  let day = (doy - (153L * month_prime + 2L) / 5L + 1L).to_int()
  let month_offset = if month_prime < 10L { 3L } else { -9L }
  let month = (month_prime + month_offset).to_int()
  let year_offset = if month <= 2 { 1L } else { 0L }
  let year = (year_base + year_offset).to_int()
  (year, month, day)
}

///|
pub fn days_from_civil(year : Int, month : Int, day : Int) -> Int64 {
  let year_offset = if month <= 2 { 1 } else { 0 }
  let adjusted_year = year - year_offset
  let era = if adjusted_year >= 0 {
    adjusted_year / 400
  } else {
    (adjusted_year - 399) / 400
  }
  let year_of_era = adjusted_year - era * 400
  let month_offset = if month > 2 { -3 } else { 9 }
  let month_prime = month + month_offset
  let day_of_year = (153 * month_prime + 2) / 5 + day - 1
  let day_of_era = year_of_era * 365 +
    year_of_era / 4 -
    year_of_era / 100 +
    day_of_year
  (era * 146_097 + day_of_era - 719_468).to_int64()
}

///|
pub fn is_leap_year(year : Int) -> Bool {
  year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

///|
pub fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 => 31
    2 => if is_leap_year(year) { 29 } else { 28 }
    3 => 31
    4 => 30
    5 => 31
    6 => 30
    7 => 31
    8 => 31
    9 => 30
    10 => 31
    11 => 30
    12 => 31
    _ => 0
  }
}

///|
fn http_month_number(month : StringView) -> Int? {
  match month {
    "Jan" => Some(1)
    "Feb" => Some(2)
    "Mar" => Some(3)
    "Apr" => Some(4)
    "May" => Some(5)
    "Jun" => Some(6)
    "Jul" => Some(7)
    "Aug" => Some(8)
    "Sep" => Some(9)
    "Oct" => Some(10)
    "Nov" => Some(11)
    "Dec" => Some(12)
    _ => None
  }
}

///|
pub fn parse_http_date_part(text : StringView) -> Int? {
  try @string.parse_int(text) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn http_weekday_name(days_since_epoch : Int64) -> String {
  match positive_mod_i64(days_since_epoch + 4L, 7L).to_int() {
    0 => "Sun"
    1 => "Mon"
    2 => "Tue"
    3 => "Wed"
    4 => "Thu"
    5 => "Fri"
    _ => "Sat"
  }
}

///|
fn http_month_name(month : Int) -> String {
  match month {
    1 => "Jan"
    2 => "Feb"
    3 => "Mar"
    4 => "Apr"
    5 => "May"
    6 => "Jun"
    7 => "Jul"
    8 => "Aug"
    9 => "Sep"
    10 => "Oct"
    11 => "Nov"
    _ => "Dec"
  }
}

///|
pub fn format_http_date(epoch_seconds : Int64) -> String {
  let days_since_epoch = floor_div_i64(epoch_seconds, HTTP_SECONDS_PER_DAY)
  let seconds_of_day = (epoch_seconds - days_since_epoch * HTTP_SECONDS_PER_DAY).to_int()
  let hour = seconds_of_day / 3_600
  let minute = seconds_of_day % 3_600 / 60
  let second = seconds_of_day % 60
  let (year, month, day) = civil_from_days(days_since_epoch)
  "\{http_weekday_name(days_since_epoch)}, \{zero_pad_2(day)} \{http_month_name(month)} \{year} \{zero_pad_2(hour)}:\{zero_pad_2(minute)}:\{zero_pad_2(second)} GMT"
}

///|
pub fn parse_http_date(http_date : StringView) -> Int64? {
  if http_date.length() != 29 {
    return None
  }
  if http_date[3:5] != ", " {
    return None
  }
  if http_date[7:8] != " " ||
    http_date[11:12] != " " ||
    http_date[16:17] != " " ||
    http_date[19:20] != ":" ||
    http_date[22:23] != ":" ||
    http_date[25:29] != " GMT" {
    return None
  }
  let day = match parse_http_date_part(http_date[5:7]) {
    Some(day) => day
    None => return None
  }
  let month = match http_month_number(http_date[8:11]) {
    Some(month) => month
    None => return None
  }
  let year = match parse_http_date_part(http_date[12:16]) {
    Some(year) => year
    None => return None
  }
  let hour = match parse_http_date_part(http_date[17:19]) {
    Some(hour) => hour
    None => return None
  }
  let minute = match parse_http_date_part(http_date[20:22]) {
    Some(minute) => minute
    None => return None
  }
  let second = match parse_http_date_part(http_date[23:25]) {
    Some(second) => second
    None => return None
  }
  if day < 1 || day > days_in_month(year, month) {
    return None
  }
  if hour < 0 || hour >= 24 {
    return None
  }
  if minute < 0 || minute >= 60 {
    return None
  }
  if second < 0 || second >= 60 {
    return None
  }
  let days_since_epoch = days_from_civil(year, month, day)
  Some(
    days_since_epoch * HTTP_SECONDS_PER_DAY +
    (hour * 3_600 + minute * 60 + second).to_int64(),
  )
}
