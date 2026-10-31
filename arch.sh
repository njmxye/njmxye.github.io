#!/data/data/com.termux/files/usr/bin/bash
folder=arch-fs
if [ -d "$folder" ]; then
	first=1
	echo "跳过下载"
fi
tarball="arch-rootfs.tar.gz"
if [ "$first" != 1 ];then
	if [ ! -f $tarball ]; then
		echo "下载Rootfs中，这可能需要一段时间，具体取决于您的互联网速度。"
		case `dpkg --print-architecture` in
		aarch64)
			archurl="aarch64" ;;
		arm)
			archurl="armv7" ;;
		*)
			echo "unknown architecture"; exit 1 ;;
		esac
		wget "https://mirrors.tuna.tsinghua.edu.cn/archlinuxarm/os/ArchLinuxARM-aarch64-latest.tar.gz" -O $tarball
	fi
	cur=`pwd`
	mkdir -p "$folder"
	cd "$folder"
	echo "解压Rootfs中，请耐心等待。"
	proot --link2symlink tar -xf ${cur}/${tarball}||:
	cd "$cur"
fi
mkdir -p arch-binds
bin=start-arch.sh
echo "编写启动脚本中"
cat > $bin <<- EOM
#!/bin/bash
echo " "
echo " "
echo " "
echo "如果您是第一次启动 Arch Linux，您应该运行以下命令： chmod 755 additional.sh && ./additional.sh , 这将修复pacman-key和network的相关问题。"
echo " "
echo " "
echo " "
cd \$(dirname \$0)
pulseaudio --start
## For rooted user: pulseaudio --start --system
## unset LD_PRELOAD in case termux-exec is installed
unset LD_PRELOAD
command="proot"
command+=" --link2symlink"
command+=" -0"
command+=" -r $folder"
if [ -n "\$(ls -A arch-binds)" ]; then
    for f in arch-binds/* ;do
      . \$f
    done
fi
command+=" -b /dev"
command+=" -b /proc"
command+=" -b arch-fs/root:/dev/shm"
## uncomment the following line to have access to the home directory of termux
#command+=" -b /data/data/com.termux/files/home:/root"
## uncomment the following line to mount /sdcard directly to / 
#command+=" -b /sdcard"
command+=" -w /root"
command+=" /usr/bin/env -i"
command+=" HOME=/root"
command+=" PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games"
command+=" TERM=\$TERM"
command+=" LANG=C.UTF-8"
command+=" /bin/bash --login"
com="\$@"
if [ -z "\$1" ];then
    exec \$command
else
    \$command -c "\$com"
fi
EOM

echo "正在设置pulseaudio，以便您可以在distro中播放音乐。"

pkg install pulseaudio -y

if grep -q "anonymous" ~/../usr/etc/pulse/default.pa;then
    echo "module already present"
else
    echo "load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" >> ~/../usr/etc/pulse/default.pa
fi

echo "exit-idle-time = -1" >> ~/../usr/etc/pulse/daemon.conf
echo "Modified pulseaudio timeout to infinite"
echo "autospawn = no" >> ~/../usr/etc/pulse/client.conf
echo "Disabled pulseaudio autospawn"
echo "export PULSE_SERVER=127.0.0.1" >> arch-fs/etc/profile
echo "Setting Pulseaudio server to 127.0.0.1"

echo "fixing shebang of $bin"
termux-fix-shebang $bin
echo "making $bin executable"
chmod +x $bin
echo "正在删除映像文件以清理多余空间"
rm $tarball
echo "您现在可以使用 ./${bin} 脚本启动 Arch Linux"
echo "为首次启动准备附加组件中，请稍候..."
wget "https://sourceforge.net/projects/anotherday99/files/resolv.conf" -P arch-fs/root
wget "https://sourceforge.net/projects/anotherday99/files/additional.sh" -P arch-fs/root
echo "完成"
