#!/bin/bash

# cachify-arch.sh - CachyOS performans optimizasyonlarını, Fish shell yapılandırmasını ve
# ek geliştirici paketlerini saf Arch Linux'a uygulayan betik.
#
# UYARI: Bu betik, sisteminizde köklü değişiklikler yapacaktır. Paketlerinizin
# önemli bir kısmı CachyOS depolarından gelenlerle değiştirilecektir.
# Devam etmeden önce önemli verilerinizi yedeklediğinizden emin olun.
#
# Bu betik, yalnızca UEFI üzerinde systemd-boot kullanan Arch Linux sistemleri
# için tasarlanmıştır.

set -euo pipefail

# Renk kodları
GREEN='\033${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}${NC} $1"
}

log_error() {
    echo -e "${RED}${NC} $1" >&2
    exit 1
}

# --- Güvenlik Kontrolleri ve Ön Hazırlık ---
pre_flight_checks() {
    log_info "Ön kontrol işlemleri başlatılıyor..."

    # 1. Root yetkisi kontrolü
    if]; then
        log_error "Bu betik root yetkileriyle çalıştırılmalıdır. Lütfen 'sudo./cachify-arch.sh' komutunu kullanın."
    fi

    # 2. İnternet bağlantısı kontrolü
    if! ping -c 1 -W 3 cachyos.org &> /dev/null; then
        log_error "İnternet bağlantısı kurulamadı. CachyOS depolarına erişim gerekli."
    fi

    # 3. systemd-boot kontrolü
    if! bootctl status &> /dev/null |

| [[! -d /boot/loader/entries ]]; then
        log_error "systemd-boot algılanamadı. Bu betik yalnızca systemd-boot kullanan sistemler için tasarlanmıştır."
    fi

    # 4. pacman.conf yedeği
    if [[ -f /etc/pacman.conf.bak.pre-cachyos ]]; then
        log_warn "/etc/pacman.conf.bak.pre-cachyos dosyası zaten mevcut. Yedekleme atlanıyor."
    else
        log_info "/etc/pacman.conf dosyası /etc/pacman.conf.bak.pre-cachyos olarak yedekleniyor."
        cp /etc/pacman.conf /etc/pacman.conf.bak.pre-cachyos
    fi
    
    log_info "Tüm ön kontroller başarıyla tamamlandı."
}

# --- CachyOS Depolarını Kurulumu ---
setup_repositories() {
    log_info "CachyOS depoları kuruluyor..."
    
    # cachyos-repo betiğini indir ve çalıştır
    local SCRIPT_DIR
    SCRIPT_DIR=$(mktemp -d)
    
    log_info "CachyOS depo kurulum betiği indiriliyor..."
    curl -L 'https://mirror.cachyos.org/cachyos-repo.tar.xz' -o "${SCRIPT_DIR}/cachyos-repo.tar.xz"
    
    log_info "Betik arşivden çıkarılıyor..."
    tar -xf "${SCRIPT_DIR}/cachyos-repo.tar.xz" -C "$SCRIPT_DIR"
    
    # cachyos-repo.sh betiğini çalıştır
    # Bu betik CPU mimarisini otomatik algılar, GPG anahtarını kurar ve pacman.conf'u günceller.
    log_info "CachyOS depo kurulum betiği çalıştırılıyor. Bu işlem CPU mimarinizi algılayacak."
    if! (cd "${SCRIPT_DIR}/cachyos-repo" &&./cachyos-repo.sh); then
        log_error "CachyOS depo kurulumu başarısız oldu."
    fi
    
    rm -rf "$SCRIPT_DIR"
    log_info "CachyOS depoları başarıyla kuruldu ve pacman.conf güncellendi."
}

# --- Paketleri CachyOS Sürümlerine Geçirme ---
migrate_packages() {
    log_info "Sistem paketleri CachyOS'un optimize edilmiş sürümlerine geçiriliyor..."
    log_warn "Bu işlem uzun sürebilir ve çok sayıda paket indirilecektir."
    
    # Depo veritabanlarını senkronize et
    pacman -Sy
    
    # Tüm kurulu paketleri CachyOS depolarındaki sürümlerle değiştirmek için zorla güncelleme yap.
    # pacman -Syuu, paketlerin daha yeni sürüm olsalar bile depo önceliğine göre değiştirilmesini sağlar.
    if! pacman -Syuu --noconfirm; then
        log_error "Paket geçişi sırasında bir hata oluştu."
    fi
    
    log_info "Tüm sistem paketleri CachyOS sürümlerine başarıyla geçirildi."
}

# --- Çekirdek CachyOS Bileşenlerini Kurma ---
install_core_components() {
    log_info "Temel CachyOS bileşenleri kuruluyor..."
    
    # Gerekli paketler listesi
    local packages_to_install=(
        "linux-cachyos"              # BORE zamanlayıcılı ana kernel
        "linux-cachyos-headers"      # DKMS modülleri için gerekli başlık dosyaları
        "cachyos-settings"           # sysctl, udev, modprobe ayarları
        "ananicy-cpp"                # Otomatik işlem önceliklendirme servisi
        "cachyos-ananicy-rules"      # anicy-cpp için kural seti
        "zram-generator"             # systemd tabanlı ZRAM yapılandırması
        "cachyos-fish-config"        # CachyOS'un varsayılan Fish shell ayarları
    )
    
    log_info "Kurulacak paketler: ${packages_to_install[*]}"
    
    if! pacman -S --noconfirm --needed "${packages_to_install[@]}"; then
        log_error "Temel CachyOS bileşenleri kurulurken bir hata oluştu."
    fi
    
    log_info "Temel bileşenler başarıyla kuruldu."
}

# --- Fish Shell Kurulumu ve Yapılandırması ---
setup_fish_shell() {
    log_info "Fish shell ve modern terminal araçları kuruluyor..."

    # Gerekli paketleri kur: fish, starship (prompt), fzf (fuzzy finder)
    if! pacman -S --noconfirm --needed fish starship fzf; then
        log_error "Fish shell veya bağımlılıkları kurulurken bir hata oluştu."
    fi

    # Betiği çalıştıran asıl kullanıcının adını al
    local real_user
    real_user=$(logname)
    if [[ -z "$real_user" ]]; then
        log_error "Asıl kullanıcı adı alınamadı. 'logname' komutu başarısız oldu."
    fi
    log_info "Yapılandırma '$real_user' kullanıcısı için yapılacak."

    # Kullanıcının varsayılan kabuğunu Fish olarak değiştir
    log_info "'$real_user' kullanıcısının varsayılan kabuğu /usr/bin/fish olarak ayarlanıyor."
    if! chsh -s /usr/bin/fish "$real_user"; then
        log_warn "chsh komutu başarısız oldu. Kabuk manuel olarak değiştirilmelidir."
        log_warn "Komut: chsh -s /usr/bin/fish $real_user"
    fi

    # Fisher (plugin manager), eklentiler ve Starship yapılandırması
    # Bu komutlar asıl kullanıcı olarak çalıştırılmalıdır.
    log_info "Fisher eklenti yöneticisi ve eklentiler kuruluyor..."
    if! sudo -u "$real_user" fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"; then
        log_error "Fisher kurulumu başarısız oldu."
    fi

    log_info "Popüler Fish eklentileri kuruluyor: z, fzf.fish, pisces..."
    if! sudo -u "$real_user" fish -c "fisher install jethrokuan/z patrickf1/fzf.fish laughedelic/pisces"; then
        log_error "Fisher eklentileri kurulurken bir hata oluştu."
    fi

    log_info "Starship prompt, Fish için etkinleştiriliyor..."
    # Yapılandırma dosyasının var olup olmadığını kontrol et ve yoksa oluştur
    local fish_config_file="/home/$real_user/.config/fish/config.fish"
    sudo -u "$real_user" mkdir -p "$(dirname "$fish_config_file")"
    sudo -u "$real_user" touch "$fish_config_file"

    # Starship'in zaten ekli olup olmadığını kontrol et
    if! sudo -u "$real_user" grep -q "starship init fish" "$fish_config_file"; then
        echo -e "\n# Starship Prompt\nstarship init fish | source" | sudo -u "$real_user" tee -a "$fish_config_file" > /dev/null
        log_info "Starship yapılandırması $fish_config_file dosyasına eklendi."
    else
        log_warn "Starship yapılandırması $fish_config_file dosyasında zaten mevcut."
    fi

    log_info "Fish shell yapılandırması tamamlandı."
}

# --- Geliştirici Araçları ve AUR Yardımcısı Kurulumu ---
install_dev_tools() {
    log_info "Geliştirici araçları, Paru ve Google Chrome kuruluyor..."

    # Gerekli paketleri pacman ile kur
    log_info "Temel geliştirme araçları (git, python-pip, go, base-devel) kuruluyor."
    if! pacman -S --noconfirm --needed git python-pip go base-devel; then
        log_error "Geliştirici araçları kurulurken bir hata oluştu."
    fi

    # pacman'de renkli çıktıyı etkinleştir (paru için de gerekli)
    log_info "Pacman için renkli çıktı etkinleştiriliyor."
    sed -i 's/^#Color/Color/' /etc/pacman.conf

    # Betiği çalıştıran asıl kullanıcıyı al
    local real_user
    real_user=$(logname)
    if [[ -z "$real_user" ]]; then
        log_error "Asıl kullanıcı adı alınamadı. 'logname' komutu başarısız oldu."
    fi
    log_info "AUR işlemleri '$real_user' kullanıcısı adına yapılacak."

    # Paru ve Chrome'u kurmak için geçici olarak şifresiz sudo hakkı ver
    local sudoer_file="/etc/sudoers.d/99-temp-cachy-installer"
    echo "$real_user ALL=(ALL) NOPASSWD: /usr/bin/pacman" > "$sudoer_file"
    log_info "Paru kurulumu için geçici sudo kuralı oluşturuldu."

    # Paru'yu kur
    log_info "Paru (AUR Helper) kuruluyor..."
    local paru_dir="/tmp/paru-build"
    if! sudo -u "$real_user" bash -c "mkdir -p $paru_dir && cd $paru_dir && git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -si --noconfirm"; then
        rm -f "$sudoer_file" # Hata durumunda kuralı temizle
        log_error "Paru kurulumu başarısız oldu."
    fi
    log_info "Paru başarıyla kuruldu."

    # Google Chrome'u Paru ile kur
    log_info "Google Chrome, Paru kullanılarak kuruluyor..."
    if! sudo -u "$real_user" paru -S --noconfirm --needed google-chrome; then
        rm -f "$sudoer_file" # Hata durumunda kuralı temizle
        log_error "Google Chrome kurulumu başarısız oldu."
    fi
    log_info "Google Chrome başarıyla kuruldu."

    # Geçici sudo kuralını ve build dizinini temizle
    rm -f "$sudoer_file"
    rm -rf "$paru_dir"
    log_info "Geçici sudo kuralı ve build dosyaları temizlendi."
    log_info "Geliştirici araçları kurulumu tamamlandı."
}

# --- Servisleri Yapılandırma ve Etkinleştirme ---
configure_services() {
    log_info "Gerekli sistem servisleri etkinleştiriliyor..."

    # Ananicy servisini etkinleştir ve başlat
    log_info "ananicy-cpp servisi etkinleştiriliyor."
    systemctl enable --now ananicy-cpp.service
    
    # ZRAM servisini etkinleştir ve başlat
    log_info "systemd-zram-setup servisi etkinleştiriliyor."
    # zram-generator, zram0 için otomatik olarak birim oluşturur.
    systemctl enable --now systemd-zram-setup@zram0.service

    log_info "Servisler başarıyla yapılandırıldı."
}

# --- Önyükleyiciyi Güncelleme ---
update_bootloader() {
    log_info "systemd-boot önyükleyicisi yeni kernel için güncelleniyor..."
    
    # bootctl, /boot dizinindeki yeni kernelleri otomatik olarak algılar ve menüyü günceller.
    if! bootctl update; then
        log_error "bootctl update komutu başarısız oldu. Önyükleyici güncellenemedi."
    fi
    
    log_info "Önyükleyici başarıyla güncellendi. Yeni 'linux-cachyos' kerneli bir sonraki açılışta seçilebilir olmalıdır."
}

# --- Ana Fonksiyon ---
main() {
    log_info "CachyOS'laştırma süreci başlıyor..."
    
    pre_flight_checks
    setup_repositories
    migrate_packages
    install_core_components
    setup_fish_shell
    install_dev_tools
    configure_services
    update_bootloader
    
    log_info "${GREEN}=====================================================${NC}"
    log_info "${GREEN}CachyOS'laştırma işlemi başarıyla tamamlandı!${NC}"
    log_warn "Değişikliklerin tam olarak uygulanması için sisteminizi yeniden başlatmanız şiddetle tavsiye edilir."
    log_info "Yeniden başlattıktan sonra, önyükleme menüsünden 'CachyOS' kernelini seçtiğinizden emin olun."
    log_info "Yeni terminal oturumlarınızda varsayılan olarak modern özelliklere sahip Fish shell kullanılacaktır."
    log_info "Ek olarak, 'git', 'python-pip', 'go', 'paru' ve 'google-chrome' kuruldu."
    log_info "${GREEN}=====================================================${NC}"
}

# Betiği çalıştır
main
