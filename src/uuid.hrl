-define(VARIANT10, 2#10).


%% For 100 nanosecond interval transformation in UUIDv1.

%% Offset between 15 October 1582 and 1 January 1970
-define(nanosecond_intervals_offset, 122192928000000000).

%% microseconds to nanoseconds
-define(nanosecond_intervals_factor, 10).


%% Version
-define(UUIDv1, 1).
-define(UUIDv3, 3).
-define(UUIDv4, 4).
-define(UUIDv5, 5).