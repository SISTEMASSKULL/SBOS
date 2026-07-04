package k8s

import (
	"fmt"
	"strings"

	"bos/internal/tui/ctrl/dash"
	"bos/internal/tui/styles"
)

// Storage renderiza la vista K8s — Storage.
func Storage(dm dash.DashModel, w, h int) string {
	if w < 30 || h < 4 {
		return styles.Dim.Render("Vista no disponible — terminal demasiado pequeño")
	}
	tabs := []string{"PVs", "PVCs", "StorageClasses", "VolumeSnaps"}
	tabIdx := dm.SubTab["k8s-sto"]
	bar := dash.SubTabs(tabs, tabIdx, w)
	var lines []string
	lines = append(lines, bar, "")

	switch tabIdx {
	case 0: // PVs
		lines = append(lines, dash.SectionHeader("PERSISTENT VOLUMES"), "")
		cols := dash.ColWidths(w, []int{18, 7, 6, 9, 9, 14, 30, 7})
		nameW, capW, accW, rclW, stW, scW, claimW, _ :=
			cols[0], cols[1], cols[2], cols[3], cols[4], cols[5], cols[6], cols[7]
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(nameW).Render("NOMBRE"),
				styles.TableHeader.Width(capW).Render("CAP"),
				styles.TableHeader.Width(accW).Render("ACC"),
				styles.TableHeader.Width(rclW).Render("RECLAIM"),
				styles.TableHeader.Width(stW).Render("STATUS"),
				styles.TableHeader.Width(scW).Render("STORAGECLASS"),
				styles.TableHeader.Width(claimW).Render("CLAIM"),
				styles.TableHeader.Render("AGE"),
			),
			dash.ColSep(w),
		)
		for _, pv := range dm.PVs {
			stColor := styles.StatusOK
			if pv.PVStatus != "Bound" {
				stColor = styles.StatusWarn
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(nameW).Render(dash.Truncate(pv.Name, nameW-1)),
				styles.AccentBold.Width(capW).Render(pv.Capacity),
				styles.Dim.Render(fmt.Sprintf("%-*s", accW, pv.AccessMode)),
				styles.Dim.Render(fmt.Sprintf("%-*s", rclW, pv.ReclaimPolicy)),
				stColor.Render(fmt.Sprintf("%-*s", stW, pv.PVStatus)),
				styles.Dim.Render(fmt.Sprintf("%-*s", scW, dash.Truncate(pv.StorageClass, scW-1))),
				styles.Dim.Render(fmt.Sprintf("%-*s", claimW, dash.Truncate(pv.Claim, claimW-1))),
				styles.Dim.Render(pv.Age),
			))
		}
	case 1: // PVCs
		lines = append(lines, dash.SectionHeader("PERSISTENT VOLUME CLAIMS"), "")
		cols := dash.ColWidths(w, []int{18, 12, 9, 16, 7, 6, 25, 7})
		nameW, nsW, stW, volW, capW, accW, scW, _ :=
			cols[0], cols[1], cols[2], cols[3], cols[4], cols[5], cols[6], cols[7]
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(nameW).Render("NOMBRE"),
				styles.TableHeader.Width(nsW).Render("NS"),
				styles.TableHeader.Width(stW).Render("STATUS"),
				styles.TableHeader.Width(volW).Render("VOLUME"),
				styles.TableHeader.Width(capW).Render("CAP"),
				styles.TableHeader.Width(accW).Render("ACC"),
				styles.TableHeader.Width(scW).Render("STORAGECLASS"),
				styles.TableHeader.Render("AGE"),
			),
			dash.ColSep(w),
		)
		for _, pvc := range dm.PVCs {
			stColor := styles.StatusOK
			if pvc.PVCStatus != "Bound" {
				stColor = styles.StatusWarn
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(nameW).Render(dash.Truncate(pvc.Name, nameW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", nsW, dash.Truncate(pvc.Namespace, nsW-1))),
				stColor.Render(fmt.Sprintf("%-*s", stW, pvc.PVCStatus)),
				styles.Dim.Render(fmt.Sprintf("%-*s", volW, dash.Truncate(pvc.Volume, volW-1))),
				styles.AccentBold.Width(capW).Render(pvc.Capacity),
				styles.Dim.Render(fmt.Sprintf("%-*s", accW, pvc.AccessMode)),
				styles.Dim.Render(fmt.Sprintf("%-*s", scW, dash.Truncate(pvc.StorageClass, scW-1))),
				styles.Dim.Render(pvc.Age),
			))
		}
	case 3: // VolumeSnapshots
		lines = append(lines, dash.SectionHeader("VOLUME SNAPSHOTS"), "")
		snaps := []struct{ name, ns, pvc, status, size, age string }{
			{"postgres-snap-01", "default", "postgres-pvc", "ReadyToUse", "20Gi", "2h"},
			{"redis-snap-01", "default", "redis-pvc", "ReadyToUse", "5Gi", "2h"},
			{"etcd-snap-01", "kube-system", "etcd-pvc", "ReadyToUse", "10Gi", "6h"},
		}
		cols := dash.ColWidths(w, []int{20, 14, 18, 15, 9, 24})
		nW, nsW, pvcW, stW, szW, _ :=
			cols[0], cols[1], cols[2], cols[3], cols[4], cols[5]
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(nW).Render("NOMBRE"),
				styles.TableHeader.Width(nsW).Render("NAMESPACE"),
				styles.TableHeader.Width(pvcW).Render("PVC ORIGEN"),
				styles.TableHeader.Width(stW).Render("ESTADO"),
				styles.TableHeader.Width(szW).Render("TAMAÑO"),
				styles.TableHeader.Render("AGE"),
			),
			dash.ColSep(w),
		)
		for _, s := range snaps {
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(nW).Render(dash.Truncate(s.name, nW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", nsW, s.ns)),
				styles.Dim.Render(fmt.Sprintf("%-*s", pvcW, s.pvc)),
				styles.StatusOK.Render(fmt.Sprintf("%-*s", stW, s.status)),
				styles.AccentBold.Width(szW).Render(s.size),
				styles.Dim.Render(s.age),
			))
		}
	default: // StorageClasses
		lines = append(lines, dash.SectionHeader("STORAGE CLASSES"), "")
		cols := dash.ColWidths(w, []int{18, 30, 9, 9, 27, 7})
		nameW, provW, rclW, defW, vbW, _ :=
			cols[0], cols[1], cols[2], cols[3], cols[4], cols[5]
		lines = append(lines,
			styles.JoinH(styles.PosTop,
				styles.TableHeader.Width(nameW).Render("NOMBRE"),
				styles.TableHeader.Width(provW).Render("PROVISIONER"),
				styles.TableHeader.Width(rclW).Render("RECLAIM"),
				styles.TableHeader.Width(defW).Render("DEFAULT"),
				styles.TableHeader.Width(vbW).Render("VOLUME BINDING"),
				styles.TableHeader.Render("AGE"),
			),
			dash.ColSep(w),
		)
		for _, sc := range dm.StorageClasses {
			def := styles.Dim.Render(fmt.Sprintf("%-*s", defW, "—"))
			if sc.IsDefault {
				def = styles.Tint(styles.IconOK, styles.ColorStateOKFg) + fmt.Sprintf("%-*s", defW-2, " SI")
			}
			lines = append(lines, styles.JoinH(styles.PosTop,
				styles.White.Width(nameW).Render(dash.Truncate(sc.Name, nameW-1)),
				styles.Dim.Render(fmt.Sprintf("%-*s", provW, dash.Truncate(sc.Provisioner, provW-1))),
				styles.Dim.Render(fmt.Sprintf("%-*s", rclW, sc.ReclaimPolicy)),
				def,
				styles.Dim.Render(fmt.Sprintf("%-*s", vbW, dash.Truncate(sc.VolumeBinding, vbW-1))),
				styles.Dim.Render(sc.Age),
			))
		}
	}
	return strings.Join(lines, "\n")
}
