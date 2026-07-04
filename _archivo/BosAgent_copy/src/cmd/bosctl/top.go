package main

import (
	"fmt"

	"bos/internal/observability"
)

func cmdTop(args []string) int {
	snap := observability.CollectTopSnapshot()
	fmt.Println(snap.Format())
	return 0
}
