package eventbus

import "time"

// timeNow permite reemplazar time.Now en tests.
var timeNow = time.Now
