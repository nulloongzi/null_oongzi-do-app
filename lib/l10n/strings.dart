// strings.dart — 한/영 문자열 사전. 웹 i18n.js 딕셔너리 포팅(주요 화면).
// 등록 폼은 한국어 유지(개설자 대상). 소비 동선(둘러보기·상세·공유·프로필·도시락)은 한/영.
const Map<String, Map<String, String>> kStrings = {
  // 공통
  'brand': {'ko': '누룽지도', 'en': 'Nurungjido'},
  'cancel': {'ko': '취소', 'en': 'Cancel'},
  'confirm': {'ko': '확인', 'en': 'OK'},
  'delete': {'ko': '삭제', 'en': 'Delete'},
  'edit': {'ko': '수정', 'en': 'Edit'},
  'save': {'ko': '저장', 'en': 'Save'},

  // 로그인
  'login_subtitle': {
    'ko': '우리 동네 배구, 여기서',
    'en': 'Your neighborhood volleyball',
  },
  'login_google': {'ko': '구글로 로그인', 'en': 'Sign in with Google'},
  'login_kakao': {'ko': '카카오로 로그인', 'en': 'Sign in with Kakao'},
  'login_naver': {'ko': '네이버로 로그인', 'en': 'Sign in with Naver'},
  'login_last_used': {'ko': '지난번에 사용', 'en': 'Last used'},
  'login_cancelled': {'ko': '로그인이 취소되었어요.', 'en': 'Login was cancelled.'},
  'login_kakao_fail': {'ko': '카카오 로그인 실패', 'en': 'Kakao sign-in failed'},
  'login_naver_fail': {'ko': '네이버 로그인 실패', 'en': 'Naver sign-in failed'},

  // 로그인 진행 안내 레이어 (widgets/auth_loading_layer.dart)
  'auth_signing_in': {'ko': '로그인 중이에요', 'en': 'Signing you in…'},
  'auth_signing_in_desc': {
    'ko': '계정을 확인하고 있어요. 잠시만 기다려 주세요 🍚',
    'en': 'Verifying your account. This only takes a moment 🍚',
  },
  'auth_slow_hint': {
    'ko': '조금 오래 걸리고 있어요. 네트워크 상태를 확인해 주세요.',
    'en': 'This is taking longer than usual. Please check your connection.',
  },
  'auth_close': {'ko': '닫기', 'en': 'Close'},
  'email': {'ko': '이메일', 'en': 'Email'},
  'password': {'ko': '비밀번호 (6자 이상)', 'en': 'Password (6+ chars)'},
  'sign_in': {'ko': '로그인', 'en': 'Sign in'},
  'sign_up': {'ko': '회원가입', 'en': 'Sign up'},

  // 지도 / 상단바
  'clubs': {'ko': '동호회', 'en': 'Clubs'},
  'pickup': {'ko': '픽업', 'en': 'Pickup'},
  'add': {'ko': '등록', 'en': 'Add'},
  'my_profile': {'ko': '내 프로필', 'en': 'My profile'},
  'search_ph': {'ko': '팀명, 지역으로 검색...', 'en': 'Search by team or area...'},
  'search_filter': {'ko': '검색·필터', 'en': 'Search & filter'},
  'english_only': {'ko': 'English OK만', 'en': 'English OK only'},
  'data_load_err': {'ko': '데이터 로드 오류', 'en': 'Data load error'},
  'map_view': {'ko': '지도', 'en': 'Map'},
  'list_view': {'ko': '목록', 'en': 'List'},
  'pk_empty': {'ko': '주변에 등록된 픽업이 없어요', 'en': 'No pickups registered yet'},
  'pk_region_all': {'ko': '지역 전체', 'en': 'All regions'},
  'pk_level_all': {'ko': '레벨 전체', 'en': 'All levels'},
  'filter_level': {'ko': '레벨', 'en': 'Level'},
  'pk_curated_note': {
    'ko': '공개된 인스타 정보를 보고 누룽지가 모아둔 크루예요. 직접 등록한 팀이 아니에요.',
    'en':
        'Collected by Nulloongzi from public Instagram info — not submitted by the crew itself.',
  },
  'pk_curated_takedown': {
    'ko': '우리 팀이에요 · 수정/삭제 요청',
    'en': 'This is us · request edit/removal',
  },
  'pk_takedown_subject': {
    'ko': '[누룽지도] 픽업 크루 수정/삭제 요청',
    'en': '[Nulloongzi-do] Pickup crew edit/removal request',
  },
  'pk_takedown_body': {
    'ko': '아래 크루에 대해 수정 또는 삭제를 요청합니다. (확인 후 바로 처리해 드릴게요)',
    'en':
        'I request an edit or removal for the crew below. (We will action it as soon as we verify.)',
  },
  'pk_list_share': {'ko': '목록 공유', 'en': 'Share list'},
  'pk_no_map_hint': {
    'ko': '장소가 유동적인 크루 {n}곳은 지도에 없어요 — 목록에서 확인하세요',
    'en': "{n} crew(s) without a fixed venue aren't on the map — see the list",
  },

  // 칩 라벨
  'sport_6s': {'ko': '6인제', 'en': '6s'},
  'sport_9s': {'ko': '9인제', 'en': '9s'},
  'sport_mixed': {'ko': '혼성·자유', 'en': 'Mixed'},
  // 레벨 라벨: KO는 한국식, EN은 USAV 성인부 문자 등급(B/BB/A/AA·Open).
  // 저장값은 동일 — 외국인은 문자 등급을 알고 한국인은 모르기 때문에 라벨만 갈랐다.
  'lv_beginner': {'ko': '입문', 'en': 'B · Beginner'},
  'lv_intermediate': {'ko': '중급', 'en': 'BB · Intermediate'},
  'lv_advanced': {'ko': '상급', 'en': 'A · Competitive'},
  'lv_elite': {'ko': '선출·대학팀급', 'en': 'AA/Open · Collegiate+'},
  'lv_any': {'ko': '누구나 환영', 'en': 'All welcome'},

  // 각 레벨 한 줄 설명 — 등록 폼·필터 양쪽에 노출한다.
  'lv_beginner_desc': {
    'ko': '배구 처음 · 기본기 배우는 중',
    'en': 'New to volleyball, learning the basics',
  },
  'lv_intermediate_desc': {
    'ko': '규칙·로테이션 이해 · 패스/셋/스파이크 어느 정도',
    'en': 'Know rules & rotations; pass/set/hit fairly consistently',
  },
  'lv_advanced_desc': {
    'ko': '경험 많고 기본기 탄탄 · 팀 공수 전술 이해',
    'en': 'Experienced, solid skills, knows team offense/defense',
  },
  'lv_elite_desc': {
    'ko': '선수 출신 또는 대학팀급',
    'en': 'Collegiate-level ability or equivalent',
  },
  'lv_any_desc': {'ko': '실력 상관없이 누구나', 'en': 'Anyone, any level'},

  // 자가 선택 가이드 — 미국 오픈짐들이 공통으로 붙이는 문구. 레벨 제도를 굴러가게 하는 장치다.
  'pk_level_hint': {
    'ko': '애매하면 낮은 쪽을 골라주세요. 남과 비교하지 말고 설명 기준으로요.',
    'en':
        'When in doubt, pick the lower level. Judge by the description, not by other players.',
  },
  'beginner_ok': {'ko': '🌱 초보환영', 'en': '🌱 Beginners'},
  'english_ok': {'ko': '🌐 English OK', 'en': '🌐 English OK'},

  // 상세
  'this_week': {'ko': '이번주', 'en': 'This week'},
  'urgent': {'ko': '🔥 급구', 'en': '🔥 Urgent'},
  'chat_join': {'ko': '💬 단톡 들어가기', 'en': '💬 Join chat'},
  'share_btn': {'ko': '📤 공유하기', 'en': '📤 Share'},
  'bookmark_btn': {'ko': '🍱 도시락에 담기', 'en': '🍱 Add to lunchbox'},
  'insta_btn': {'ko': '📷 인스타', 'en': '📷 Instagram'},
  'home_btn': {'ko': '🔗 홈페이지', 'en': '🔗 Website'},
  'directions_btn': {'ko': '🚀 길찾기', 'en': '🚀 Directions'},
  'verify_btn': {'ko': '인증 신청 (사진 제출)', 'en': 'Apply for verification'},
  'verify_done': {
    'ko': '인증 신청 완료! 검토 후 반영돼요',
    'en': 'Verification requested! Pending review',
  },
  'vf_pending': {
    'ko': '⏳ 인증 심사 중입니다. 관리자 확인 후 인증 배지가 부여됩니다.',
    'en': '⏳ Verification under review. A badge is granted after admin review.',
  },
  'vf_rejected': {'ko': '❌ 인증이 거절되었습니다', 'en': '❌ Verification rejected'},
  'vf_reason': {'ko': '사유: ', 'en': 'Reason: '},
  'vf_no_reason': {'ko': '사유가 기재되지 않았습니다.', 'en': 'No reason was provided.'},
  'vf_reapply': {'ko': '🔄 인증 재신청', 'en': '🔄 Re-apply'},
  'urgent_on': {'ko': '🔥 급구 올리기', 'en': '🔥 Post urgent'},
  'urgent_off': {'ko': '급구 내리기', 'en': 'Remove urgent'},
  'urgent_msg_hint': {
    'ko': '예: 이번주 토 세터 1명 급구!',
    'en': 'e.g. Need 1 setter this Sat!',
  },
  'modify_delete_title': {'ko': '삭제할까요?', 'en': 'Delete?'},
  'modify_delete_body': {
    'ko': '이 작업은 되돌릴 수 없어요.',
    'en': "This can't be undone.",
  },

  // 공유 메뉴
  'share_title': {'ko': '공유하기', 'en': 'Share'},
  'share_story': {'ko': '📸 인스타 스토리', 'en': '📸 Instagram Story'},
  'share_story_hint': {
    'ko': '링크 자동 복사 — 보는 사람은 탭 1번에 입장',
    'en': 'Link auto-copied — 1 tap to open',
  },
  'share_copy': {'ko': '🔗 링크 복사', 'en': '🔗 Copy link'},
  'share_more': {'ko': '📤 다른 앱으로 공유', 'en': '📤 Share to other apps'},
  'link_copied': {'ko': '링크가 복사됐어요', 'en': 'Link copied'},
  'story_link_hint': {
    'ko': '링크 복사됨 — 스토리에 "링크 스티커"로 붙여넣으면 탭 1번에 입장돼요',
    'en': 'Link copied — paste as a "link sticker" in your Story',
  },
  'coach_title': {'ko': "스토리에 '링크 스티커' 붙이기", 'en': 'Add a "link sticker"'},
  'coach_steps': {
    'ko':
        '링크는 이미 복사됐어요! 인스타 편집 화면에서:\n\n①  상단 스티커 아이콘 탭\n②  "링크" 선택\n③  붙여넣기 → 완료\n\n그러면 보는 사람이 탭 1번에 들어와요.\n(안 붙여도 카드의 QR·주소로 입장 가능)',
    'en':
        'Link already copied! In the Instagram editor:\n\n1.  Tap the sticker icon (top)\n2.  Choose "Link"\n3.  Paste → done\n\nThen viewers open it in 1 tap.\n(Or they can use the QR/URL on the card.)',
  },
  'coach_go': {'ko': '인스타로 이동', 'en': 'Open Instagram'},
  'coach_dont_show': {'ko': '다시 보지 않기', 'en': "Don't show again"},

  // 프로필
  'profile_title': {'ko': '내 프로필', 'en': 'My profile'},
  'my_lunchbox': {
    'ko': '내 도시락 (찜한 팀·식단표)',
    'en': 'My lunchbox (saved teams & schedule)',
  },
  'share_image_title': {'ko': '이미지로 공유', 'en': 'Share as image'},
  'share_image_btn': {'ko': '이미지로 공유 / 저장', 'en': 'Share / save image'},
  'share_wrap': {'ko': '🎁 포장하기', 'en': '🎁 Wrap it up'},
  'change_nickname': {'ko': '닉네임 변경', 'en': 'Change nickname'},
  'logout': {'ko': '로그아웃', 'en': 'Log out'},
  'joined': {'ko': '가입', 'en': 'Joined'},
  'nickname_hint': {'ko': '새 닉네임 (하이픈 - 금지)', 'en': 'New nickname (no hyphen)'},
  'nickname_hyphen': {
    'ko': '하이픈(-)은 밥아저씨가 지어준 이름에만 쓸 수 있어요',
    'en': 'Hyphens are only for auto-generated names',
  },
  'nickname_dup': {
    'ko': '이미 누군가 쓰고 있는 이름이에요',
    'en': 'That name is already taken',
  },
  'nickname_done': {'ko': '닉네임 변경 완료!', 'en': 'Nickname updated!'},

  // 도시락
  'lunchbox_title': {'ko': '도시락 🍱', 'en': 'Lunchbox 🍱'},
  'lb_diet': {'ko': '📅 식단표 (스케줄 확인)', 'en': '📅 Weekly menu'},
  'lb_diet_collapse': {'ko': '📅 식단표 접기', 'en': '📅 Hide weekly menu'},
  'expand': {'ko': '펼치기', 'en': 'Expand'},
  'collapse': {'ko': '접기', 'en': 'Collapse'},
  'add_custom': {'ko': '커스텀 팀 추가', 'en': 'Add custom team'},
  'deleted_team': {'ko': '삭제된 팀', 'en': 'Deleted team'},
  'lb_full': {'ko': '도시락이 가득 찼어요 (5칸)', 'en': 'Lunchbox is full (5)'},
  'lb_already': {'ko': '이미 도시락에 담겨 있어요', 'en': 'Already in your lunchbox'},
  'lb_added': {'ko': '도시락에 담았어요!', 'en': 'Added to lunchbox!'},
  'lb_removed': {'ko': '도시락에서 뺐어요', 'en': 'Removed from lunchbox'},
  // 상세 시트(보완): 주소 복사 · 시간표 morph 펼침 힌트
  'copy_address': {'ko': '📍 주소 복사', 'en': '📍 Copy'},
  'address_copied': {'ko': '주소를 복사했어요', 'en': 'Address copied'},
  'share_link': {'ko': '🔗 공유', 'en': '🔗 Share'}, // 컴팩트 액션 줄용
  'insta_reel_title': {
    'ko': '📷 인스타 릴스 · 게시물',
    'en': '📷 Instagram reel · post',
  },
  'insta_reel_open': {'ko': '탭하면 인스타그램에서 봐요', 'en': 'Tap to view on Instagram'},
  'reel_tap_play': {'ko': '탭하면 여기서 재생', 'en': 'Tap to play here'},
  'reels_more_label': {'ko': '릴스 더 보기', 'en': 'More reels'},
  'reels_hide': {'ko': '릴스 접기', 'en': 'Hide reels'},
  'reel_peek_hint': {
    'ko': '탭하면 재생 · 바깥을 누르면 닫기',
    'en': 'Tap to play · tap outside to close',
  },
  'reel_peek_none': {
    'ko': '이 팀은 아직 릴스가 없어요',
    'en': 'No reel for this team yet',
  },
  'detail_pull_hint': {'ko': '▴ 위로 올려 시간표 보기', 'en': '▴ Pull up for schedule'},
  'detail_collapse_hint': {'ko': '▾ 접기', 'en': '▾ Collapse'},
  'lb_slot_rice': {'ko': '밥을\n담아주세요🍚', 'en': 'Add rice 🍚'},
  'lb_slot_soup': {'ko': '국을\n담아주세요🥘', 'en': 'Add soup 🥘'},
  'lb_slot_side1': {'ko': '반찬1🍳', 'en': 'Side 1 🍳'},
  'lb_slot_side2': {'ko': '반찬2🥗', 'en': 'Side 2 🥗'},
  'lb_slot_side3': {'ko': '반찬3🥢', 'en': 'Side 3 🥢'},
  'lb_save_fail': {'ko': '저장 실패', 'en': 'Save failed'},
  'lb_save_err': {
    'ko': '저장에 실패했어요. 잠시 후 다시 시도해 주세요',
    'en': 'Save failed. Please try again.',
  },
  'err_anon_auth': {
    'ko': '로그인 처리에 실패했어요. 잠시 후 다시 시도해 주세요',
    'en': 'Sign-in failed. Please try again shortly.',
  },
  'sched_add': {'ko': '시간대 추가', 'en': 'Add time'},
  'map_pick_title': {'ko': '위치 선택', 'en': 'Pick location'},
  'map_pick_set': {'ko': '이 위치로 설정', 'en': 'Use this location'},
  'err_card': {'ko': '카드 생성에 실패했어요', 'en': "Couldn't create the card"},
  'err_share': {'ko': '공유 실패', 'en': 'Share failed'},
  'err_delete': {'ko': '삭제 실패', 'en': 'Delete failed'},
  'err_generic': {'ko': '오류', 'en': 'Error'},
  'back_exit_hint': {'ko': '한 번 더 누르면 종료돼요', 'en': 'Press back again to exit'},
  'card_title_fallback': {'ko': '배구 모임', 'en': 'Volleyball meetup'},
  'card_cta': {
    'ko': '이 팀, 어때요? 지도에서 보기 👀',
    'en': 'Check out this team on the map 👀',
  },
  'login_google_fail': {'ko': '구글 로그인 실패', 'en': 'Google sign-in failed'},
  'login_err': {'ko': '로그인 오류가 발생했어요', 'en': 'A sign-in error occurred'},
  'fab_lunchbox': {'ko': '도시락', 'en': 'Lunchbox'},
  'fab_profile': {'ko': '프로필', 'en': 'Profile'},
  'fab_register': {'ko': '등록', 'en': 'Register'},
  'fab_my_location': {'ko': '내 위치', 'en': 'My location'},
  'lb_add_name_hint': {'ko': '예: 우리 동호회', 'en': 'e.g. Our club'},
  'lb_add_sched_hint': {'ko': '토 14:00~17:00', 'en': 'Sat 14:00~17:00'},
  'lb_custom_team': {'ko': '커스텀 팀', 'en': 'Custom team'},
  'lb_remove': {'ko': '빼기', 'en': 'Remove'},
  'login_required': {'ko': '로그인이 필요해요', 'en': 'Login required'},
  'login_later': {'ko': '나중에 할게요 (둘러보기)', 'en': 'Maybe later (keep browsing)'},
  'pk_search_ph': {'ko': '픽업, 장소로 검색...', 'en': 'Search pickups or venues...'},
  'cf_owner_email': {
    'ko': '소유자 지정 (관리자 전용)',
    'en': 'Reassign owner (admin only)',
  },
  'cf_owner_email_hint': {'ko': '새 소유자 이메일', 'en': 'New owner email'},
  // 웹 reg_owner_hint/reg_owner_none 대응 — {nick}은 호출부에서 치환
  'cf_owner_current': {
    'ko': '현재 소유자: {nick} (비우면 변경 안 됨)',
    'en': 'Current owner: {nick} (leave blank to keep)',
  },
  'cf_owner_none': {
    'ko': '소유자 없음 (레거시) · 이메일 입력하여 지정',
    'en': 'No owner (legacy) · enter an email to assign',
  },
  // 웹 reg_tip 대응 — 요일별 체육관이 다르면 장소별 개별 등록 안내
  'cf_tip': {
    'ko': 'tip: 요일별로 체육관 위치가 다른 경우, 정확한 핀 표시를 위해 장소별로 각각 등록 부탁드립니다!',
    'en': 'Tip: If your gym location differs by day, please register each location separately so the map pins are accurate!',
  },
  // 웹 reg_error/pk_create_err 대응 — 실패 원문 앞에 붙는 현지화 프리픽스
  'cf_save_err': {
    'ko': '등록 중 오류가 발생했습니다: ',
    'en': 'An error occurred during registration: ',
  },
  'pf_save_err': {'ko': '게임 처리 중 오류: ', 'en': 'Something went wrong: '},
  'logout_confirm': {'ko': '로그아웃 하시겠습니까?', 'en': 'Log out?'},
  'share_mode_feed': {'ko': '피드형 (식단표 포함)', 'en': 'Feed (with schedule)'},
  'share_mode_story': {'ko': '스토리형', 'en': 'Story'},
  // 공유 카드(my_card.dart)는 Canvas에 직접 그려서 이모지가 tofu(□)로 뜬다.
  // 카드 안에 들어가는 문구는 이모지 없는 별도 키를 쓴다.
  'mycard_lunchbox': {'ko': '도시락', 'en': 'Lunchbox'},
  'mycard_timetable': {'ko': '시간표', 'en': 'Schedule'},
  // 보온도시락 스택의 각 단 — 맨 아래 밥, 그 위 국, 맨 위 반찬 3칸.
  'mycard_tier_rice': {'ko': '밥', 'en': 'Rice'},
  'mycard_tier_soup': {'ko': '국', 'en': 'Soup'},
  'mycard_tier_sides': {'ko': '반찬', 'en': 'Sides'},
  'mycard_cta': {'ko': '내 밥이름 만들러 가기', 'en': 'Get your own rice-name'},
  'lb_no_sched': {'ko': '찜한 팀의 일정이 없어요', 'en': 'No schedule for saved teams'},
  'share_kakao': {'ko': '💬 카카오톡', 'en': '💬 KakaoTalk'},
  'kakao_view_btn': {'ko': '지도에서 보기', 'en': 'View on map'},
  'lb_reorder_hint': {
    'ko': '칸을 탭해 순서 바꾸기 · ✕ 빼기',
    'en': 'Tap slots to reorder · ✕ remove',
  },
  'lb_reorder_pick': {
    'ko': '바꿀 칸을 한 번 더 탭하세요',
    'en': 'Tap another slot to swap',
  },
  'lb_edit': {'ko': '편집', 'en': 'Edit'},
  'lb_add': {'ko': '🍙 직접추가', 'en': '🍙 Add team'},
  'lb_done': {'ko': '완료', 'en': 'Done'},
  'lb_edit_hint': {
    'ko': '‘편집’을 눌러 순서 변경·빼기',
    'en': 'Tap Edit to reorder or remove',
  },
  'no_saved_team': {'ko': '아직 찜한 팀이 없어요', 'en': 'No saved teams yet'},
  'lb_team_name': {'ko': '팀 이름', 'en': 'Team name'},
  'lb_sched_hint': {
    'ko': '일정 (예: 토 14:00~17:00)',
    'en': 'Schedule (e.g. Sat 14:00~17:00)',
  },

  // 필터
  'filter_title': {'ko': '검색 · 필터', 'en': 'Search & filter'},
  'filter_search_hint': {'ko': '팀 이름·지역 검색', 'en': 'Search team or area'},
  'filter_region': {'ko': '지역', 'en': 'Region'},
  'filter_day': {'ko': '요일', 'en': 'Day'},
  'filter_target': {'ko': '대상', 'en': 'For'},
  'filter_reset': {'ko': '초기화', 'en': 'Reset'},
  'filter_apply': {'ko': '적용하기', 'en': 'Apply'},

  // 등록 폼 공통
  'f_addr_search': {'ko': '주소로 검색', 'en': 'Search by address'},
  'f_addr_map': {'ko': '지도에서', 'en': 'On map'},
  'f_loc_set': {'ko': '위치 선택됨', 'en': 'Location set'},
  'f_addr_empty': {'ko': '주소를 입력해주세요', 'en': 'Enter an address'},
  'f_addr_found': {'ko': '주소를 찾았어요!', 'en': 'Address found!'},
  'f_addr_notfound': {
    'ko': '주소를 못 찾았어요 — 지도에서 선택해주세요',
    'en': "Couldn't find it — pick on the map",
  },
  'f_pick_loc': {'ko': '지도에서 위치를 선택해주세요', 'en': 'Pick a location on the map'},
  // 웹 reg_map_loc 대응 — 역지오코딩 실패 시 주소칸 기본 문구
  'f_map_loc': {'ko': '지도에서 선택된 위치', 'en': 'Location picked on map'},
  'f_link_invalid': {
    'ko': '링크 형식이 올바르지 않아요 (http/https)',
    'en': 'Invalid link (http/https)',
  },
  'f_reel_invalid': {
    'ko': '인스타 게시물/릴스 링크 형식이 올바르지 않아요',
    'en': 'Invalid Instagram post/reel link',
  },
  'f_updated': {'ko': '수정됐어요!', 'en': 'Updated!'},
  'cf_optional_summary': {
    'ko': '추가 정보 입력 (선택)',
    'en': 'Add more details (optional)',
  },
  'cf_field_required': {'ko': '필수', 'en': 'Required'},
  'f_reel_label': {'ko': '릴스/게시물 링크 (선택)', 'en': 'Reel/post link (optional)'},
  'f_reel_hint': {
    'ko': '예: https://www.instagram.com/reel/...',
    'en': 'e.g. https://www.instagram.com/reel/...',
  },
  'reel_add': {'ko': '릴스 추가', 'en': 'Add reel'},
  'reel_first_hint': {
    'ko': '맨 위 릴스가 마커 미리보기로 표시돼요 · ≡ 꾹 눌러 순서 변경',
    'en': 'Top reel shows as the marker preview · hold ≡ to reorder',
  },
  'f_contact_hint': {
    'ko': '예: https://open.kakao.com/o/...',
    'en': 'e.g. https://open.kakao.com/o/...',
  },
  // 픽업 폼
  'pf_title': {'ko': '픽업 게임 열기', 'en': 'Open a pickup game'},
  'pf_edit_title': {'ko': '픽업 수정', 'en': 'Edit pickup'},
  'pf_submit': {'ko': '픽업 등록', 'en': 'Post pickup'},
  'pf_name': {'ko': '게임 이름 (필수)', 'en': 'Game name (required)'},
  'pf_name_hint': {
    'ko': '예: 토요일 저녁 6인제 픽업',
    'en': 'e.g. Sat evening 6s pickup',
  },
  'pf_sport': {'ko': '종목', 'en': 'Sport'},
  'pf_level': {'ko': '레벨', 'en': 'Level'},
  'pf_beginner': {'ko': '초보 환영', 'en': 'Beginners welcome'},
  'pf_english': {
    'ko': '🌐 외국인 환영 (English OK)',
    'en': '🌐 Foreigners welcome (English OK)',
  },
  'pf_venue': {'ko': '체육관/장소 이름', 'en': 'Gym / venue name'},
  'pf_venue_hint': {'ko': '예: 잠실학생체육관', 'en': 'e.g. Jamsil Student Gym'},
  'pf_region': {'ko': '지역', 'en': 'Region'},
  'pf_addr': {
    'ko': '주소 (선택 · 없으면 목록에만 표시)',
    'en': 'Address (optional — list only if blank)',
  },
  'pf_addr_hint': {
    'ko': '예: 서울 송파구 올림픽로 25',
    'en': 'e.g. 25 Olympic-ro, Songpa-gu',
  },
  'pf_sched': {'ko': '보통 일정 (요일·시간)', 'en': 'Usual schedule (day · time)'},
  'pf_sched_memo': {
    'ko': '일정 메모 (비정기·기타, 선택)',
    'en': 'Schedule note (optional)',
  },
  'pf_sched_memo_hint': {
    'ko': '예: 셋째주 휴무 · 우천시 취소',
    'en': 'e.g. off 3rd week · cancel if rain',
  },
  'pf_thisweek': {'ko': '이번주 공지 (선택)', 'en': 'This-week notice (optional)'},
  'pf_thisweek_hint': {
    'ko': '예: 이번주 토 7시 잠실',
    'en': 'e.g. this Sat 7pm Jamsil',
  },
  'pf_fee': {'ko': '게임비 정보 (선택)', 'en': 'Fee info (optional)'},
  'pf_fee_hint': {'ko': '예: 보통 1만원 · 현장', 'en': 'e.g. ~10,000 won · on-site'},
  'pf_contact': {
    'ko': '단톡/Meetup 링크 (들어가는 문)',
    'en': 'Group chat / Meetup link',
  },
  'pf_curated': {'ko': '대신 등록 (관리자)', 'en': 'Add on behalf (admin)'},
  'pf_curated_chip': {
    'ko': '🔎 공개 정보로 대신 등록',
    'en': '🔎 Added from public info',
  },
  'pf_curated_hint': {
    'ko':
        '켜면 상세에 "공개 인스타 정보로 모은 크루" 안내와 수정/삭제 요청 링크가 표시됩니다. 남의 크루를 대신 올릴 때만 켜세요.',
    'en':
        'Shows a "collected from public Instagram info" notice plus an edit/removal request link. Only for crews you add on their behalf.',
  },
  'pf_insta': {'ko': '인스타 아이디 (선택)', 'en': 'Instagram handle (optional)'},
  'pf_insta_hint': {
    'ko': '예: nulloongzi (@ 없이)',
    'en': 'e.g. nulloongzi (without @)',
  },
  'pf_notes': {'ko': '추가 안내 (선택)', 'en': 'Extra notes (optional)'},
  'pf_notes_hint': {
    'ko': '예: 실내화 필수 · 네트 6인제 높이',
    'en': 'e.g. indoor shoes · 6s net height',
  },
  'pk_f_expire': {
    'ko': '언제까지 보일까요? (지나면 자동 숨김)',
    'en': 'Show until? (auto-hidden after)',
  },
  'pk_exp_weekend': {'ko': '이번 주말', 'en': 'This weekend'},
  'pk_exp_1m': {'ko': '1개월', 'en': '1 month'},
  'pk_exp_3m': {'ko': '3개월', 'en': '3 months'},
  'pk_exp_always': {'ko': '상시', 'en': 'Always'},
  'pf_req': {'ko': '게임 이름은 필수예요', 'en': 'A name is required'},
  'pf_created': {'ko': '픽업이 등록됐어요!', 'en': 'Pickup posted!'},
  // 동호회 폼
  'cf_title': {'ko': '동호회 등록', 'en': 'Register a club'},
  'cf_edit_title': {'ko': '동호회 수정', 'en': 'Edit club'},
  'cf_submit': {'ko': '등록하기', 'en': 'Register'},
  'cf_name': {'ko': '팀 이름 (필수)', 'en': 'Team name (required)'},
  'cf_name_hint': {'ko': '예: GVT 배구클럽', 'en': 'e.g. GVT Volleyball Club'},
  'cf_target': {'ko': '대상 (필수)', 'en': 'For whom (required)'},
  'cf_target_note': {
    'ko': '기타 조건 (예: 구력 1년 이상) — 선택',
    'en': 'Other (e.g. 1+ yr exp) — optional',
  },
  'cf_addr': {
    'ko': '주소 (필수) — 실제 체육관',
    'en': 'Address (required) — actual gym',
  },
  'cf_addr_hint': {
    'ko': '예: 서울 송파구 올림픽로 424',
    'en': 'e.g. 424 Olympic-ro, Songpa-gu',
  },
  'cf_sched': {'ko': '운동 시간 (스케줄)', 'en': 'Practice times'},
  'cf_price': {'ko': '회비 및 게스트비', 'en': 'Dues & guest fee'},
  'cf_price_hint': {
    'ko': '예: 월 3만원 / 게스트 1만원',
    'en': 'e.g. 30k/mo / guest 10k',
  },
  'cf_insta': {'ko': '인스타그램 핸들 (선택)', 'en': 'Instagram handle (optional)'},
  'cf_insta_hint': {'ko': '예: gvt__official', 'en': 'e.g. gvt__official'},
  'cf_link': {'ko': '가입/문의 링크 (선택)', 'en': 'Join/contact link (optional)'},
  'cf_req': {'ko': '이름·대상·주소는 필수예요', 'en': 'Name, target, address required'},
  'cf_created': {'ko': '동호회가 등록됐어요!', 'en': 'Club registered!'},
  'cf_insta_invalid': {
    'ko': '인스타그램 핸들은 영문/숫자/언더스코어/점 1~30자만 가능합니다. (@ 제외)',
    'en': 'Instagram handle allows only letters/numbers/underscore/dot, 1–30 chars. (no @)',
  },
  'cf_name_max': {'ko': '팀 이름은 60자 이하로', 'en': 'Name must be ≤ 60 chars'},
  'cf_target_max': {'ko': '대상은 80자 이하로', 'en': 'Target must be ≤ 80 chars'},
  'cf_addr_max': {'ko': '주소는 200자 이하로', 'en': 'Address must be ≤ 200 chars'},
  'cf_price_max': {'ko': '회비는 100자 이하로', 'en': 'Dues must be ≤ 100 chars'},
  // 영어모드 필터 힌트 (외국인 6s 안내, KO는 미표시)
  'fs_en_hint': {
    'ko':
        'New to Korea? Most international players look for 6s — tap it above.',
    'en':
        'New to Korea? Most international players look for 6s — tap it above.',
  },
  // 요일 (표시 변환 i18nDay)
  'd_mon': {'ko': '월', 'en': 'Mon'},
  'd_tue': {'ko': '화', 'en': 'Tue'},
  'd_wed': {'ko': '수', 'en': 'Wed'},
  'd_thu': {'ko': '목', 'en': 'Thu'},
  'd_fri': {'ko': '금', 'en': 'Fri'},
  'd_sat': {'ko': '토', 'en': 'Sat'},
  'd_sun': {'ko': '일', 'en': 'Sun'},
  // 대상 칩
  't_adult': {'ko': '성인', 'en': 'Adult'},
  't_college': {'ko': '대학생', 'en': 'College'},
  't_youth': {'ko': '청소년', 'en': 'Youth'},
  't_any': {'ko': '무관', 'en': 'Any'},
  't_women': {'ko': '여성전용', 'en': 'Women'},
  't_men': {'ko': '남성전용', 'en': 'Men'},
  't_expro': {'ko': '선출가능', 'en': 'Ex-pro OK'},
  't_6s': {'ko': '6인제', 'en': '6s'},

  // ── 안치기 (라운드 배치 도구) — anchigi.html i18n 포팅 ──
  // HTML 태그는 제거하고 강조는 위젯 스타일로 처리한다.
  'ag_title': {'ko': '안치기', 'en': 'Lineup'},
  'ag_hero_sub': {
    'ko': '온 사람을 솥에 안치듯 넣으면 라운드 배치가 나옵니다.',
    'en': 'Add who showed up and it draws round-by-round lineups.',
  },
  'ag_tab_lineup': {'ko': '배치', 'en': 'Lineup'},
  'ag_tab_roster': {'ko': '명단', 'en': 'Roster'},
  'ag_tab_record': {'ko': '기록', 'en': 'Record'},
  'ag_tab_help': {'ko': '설명', 'en': 'Help'},

  // 온보딩(빈 명단)
  'ag_intro_title': {'ko': '안치기 시작하기', 'en': 'Get started'},
  'ag_intro_s1': {
    'ko': '명단 탭에서 사람을 추가하세요',
    'en': 'Add players on the Roster tab',
  },
  'ag_intro_s2': {'ko': '포지션을 골라주세요', 'en': 'Pick their positions'},
  'ag_intro_s3': {
    'ko': '참석 체크하고 여기서 뽑기!',
    'en': 'Check attendance and Draw here!',
  },
  'ag_intro_go': {'ko': '명단 추가하러 가기 →', 'en': 'Go to Roster →'},

  // 시간 설정
  'ag_card_time': {'ko': '시간 설정', 'en': 'Schedule'},
  'ag_lb_start': {'ko': '운동 시작', 'en': 'Session start'},
  'ag_lb_gamestart': {'ko': '게임 시작', 'en': 'Games start'},
  'ag_lb_end': {'ko': '운동 종료', 'en': 'Session end'},
  'ag_lb_pergame': {'ko': '경기당(분)', 'en': 'Per game (min)'},
  'ag_lb_rest': {'ko': '라운드 휴식(분)', 'en': 'Round rest (min)'},
  'ag_min': {'ko': '분', 'en': 'min'},
  'ag_people': {'ko': '명', 'en': ''},
  'ag_est': {'ko': '예상', 'en': 'Est.'},
  'ag_round_unit': {'ko': '라운드', 'en': ' rounds'},
  'ag_rest_word': {'ko': '휴식', 'en': 'rest'},
  'ag_ends': {'ko': '종료', 'en': 'ends'},

  // 설정
  'ag_card_settings': {'ko': '설정', 'en': 'Settings'},
  'ag_mode_abc': {'ko': 'A · B · C 고정', 'en': 'A · B · C fixed'},
  'ag_mode_abc_sub': {'ko': '차출로 채우기', 'en': 'fill by borrowing'},
  'ag_mode_free': {'ko': '자유 편성', 'en': 'Free draft'},
  'ag_mode_free_sub': {'ko': '매 경기 새로', 'en': 'new each game'},
  'ag_feel_title': {'ko': '게임 성격', 'en': 'Game feel'},
  'ag_feel_comp': {'ko': '경쟁', 'en': 'Competitive'},
  'ag_feel_comp_sub': {'ko': '주 포지션만', 'en': 'Main positions only'},
  'ag_feel_real': {'ko': '실전', 'en': 'Real'},
  'ag_feel_real_sub': {'ko': '팀당 실험 1자리', 'en': '1 open slot per team'},
  'ag_feel_mix': {'ko': '고루', 'en': 'Mixed'},
  'ag_feel_mix_sub': {'ko': '팀당 실험 2자리', 'en': '2 open slots per team'},
  'ag_feel_exp': {'ko': '경험', 'en': 'Try it'},
  'ag_feel_exp_sub': {'ko': '자리 제한 없음', 'en': 'No restriction'},
  'ag_feel_hint': {
    'ko': '실험 자리 = 주 포지션이 아닌 사람이 서는 자리. 이 수만큼만 열립니다.',
    'en':
        'An open slot is one filled by someone off their main position. Only this many are allowed.',
  },
  'ag_tpl_title': {'ko': '팀 구성', 'en': 'Team format'},
  'ag_tpl_hint': {
    'ko': '(여러 개 고르면 그중에서 골라 씁니다)',
    'en': '(pick several to choose among)',
  },
  'ag_tpl_mb2': {'ko': 'MB 2', 'en': 'MB 2'},
  'ag_tpl_mb2_desc': {'ko': '리베로 없음', 'en': 'no libero'},
  'ag_tpl_mb1li': {'ko': 'MB 1 + Li 1', 'en': 'MB 1 + Li 1'},
  'ag_tpl_mb1li_desc': {'ko': '센터 1 · 리베로 1', 'en': '1 center · 1 libero'},
  'ag_tpl_mb2li': {'ko': 'MB 2 + Li 1', 'en': 'MB 2 + Li 1'},
  'ag_tpl_mb2li_desc': {
    'ko': '리베로가 후위 센터와 교대',
    'en': 'libero swaps with back-row center',
  },
  'ag_tpl_person': {'ko': '인', 'en': '-person'},
  'ag_games_count': {'ko': '경기 수', 'en': 'Games'},
  'ag_attend': {'ko': '참석', 'en': 'Present'},
  'ag_bench_per': {'ko': '경기당 대기', 'en': 'Bench/game'},

  // 뽑기
  'ag_this_round': {'ko': '이번 라운드', 'en': 'This round'},
  'ag_draw_btn': {'ko': '배치 뽑기', 'en': 'Draw lineup'},
  'ag_drawing': {'ko': '뽑는 중…', 'en': 'Drawing…'},
  'ag_draw_hint': {
    'ko': '명단 탭에서 온 사람만 체크하고 뽑으세요. 마음에 안 들면 다시 뽑으면 됩니다.',
    'en':
        'On the Roster tab, check who came, then draw. Not happy? Just redraw.',
  },
  'ag_again': {'ko': '다시 뽑기', 'en': 'Redraw'},
  'ag_confirm_next': {'ko': '확정 · 다음 라운드', 'en': 'Confirm · next round'},
  'ag_confirm_hint': {
    'ko': '확정하면 기록에 반영돼 다음 라운드에서 출전 · 대기 · 포지션이 더 고르게 분배됩니다.',
    'en':
        'Confirming logs it, so play, bench, and positions spread more evenly next round.',
  },

  // 결과 안내
  'ag_ok_done': {'ko': '{r}R 배치 완료', 'en': 'Round {r} set'},
  'ag_ok_abc': {
    'ko': 'A · B · C 코어를 정하고 안 뛰는 팀에서 차출해 채웠습니다. 차출 표시가 붙은 사람은 원래 다른 팀입니다.',
    'en':
        'Set A · B · C cores and filled gaps by borrowing from the team sitting out. Players marked borrowed belong to another team.',
  },
  'ag_ok_free': {
    'ko': '매 경기 두 팀을 새로 짰습니다.',
    'en': 'Drafted two fresh teams for each game.',
  },
  'ag_relaxed': {
    'ko': '주 포지션만으로는 팀이 안 짜여서 실험 자리를 팀당 {n}개까지 열었습니다.',
    'en':
        'Main positions alone could not fill the teams, so up to {n} open slot(s) per team were allowed.',
  },
  'ag_core_title': {'ko': '이번 라운드 코어', 'en': 'Cores this round'},
  'ag_core_none': {'ko': '없음 (전원 차출)', 'en': 'none (all borrowed)'},
  'ag_no_c_core': {
    'ko':
        '참석 인원이 팀 인원의 정확히 2배라 C 코어가 없습니다. C는 안 뛰는 팀에서 전원 차출되므로 세 경기 모두 같은 두 팀이 붙습니다. 경기마다 상대를 섞으려면 자유 편성으로 바꿔주세요.',
    'en':
        'Attendance is exactly twice a team size, so there is no C core. C is fully borrowed from the sitting-out team, so all three games pit the same two teams. To mix opponents, switch to Free draft.',
  },
  'ag_infeasible': {
    'ko': '이 인원 · 설정으로는 배치를 만들 수 없습니다.',
    'en': "Can't build a lineup with these players and settings.",
  },

  // 코트 / 타임라인
  'ag_court_zone_short': {'ko': '존 ', 'en': 'Z'},
  'ag_timeline': {'ko': '타임라인', 'en': 'Timeline'},
  'ag_warmup': {'ko': '몸풀기', 'en': 'Warm-up'},
  'ag_game_word': {'ko': '경기', 'en': 'Game'},
  'ag_leave_word': {'ko': '퇴장', 'en': 'leaves'},
  'ag_bench_label': {'ko': '대기', 'en': 'Bench'},
  'ag_bench_none': {'ko': '없음 · 전원 출전', 'en': 'none · everyone plays'},
  'ag_borrowed': {'ko': '차출', 'en': 'borrowed'},
  'ag_team_swap': {'ko': '후위 센터와 교대', 'en': 'swaps with back-row center'},
  'ag_team_word': {'ko': 'TEAM', 'en': 'TEAM'},
  'ag_fitgap_even': {
    'ko': '두 팀 자리 적합도가 고릅니다.',
    'en': 'Both teams sit at similar position fit.',
  },
  'ag_fitgap_off': {
    'ko': '한쪽 팀이 낯선 자리를 더 맡았습니다.',
    'en': 'One team took more unfamiliar slots.',
  },

  // 과거 라운드
  'ag_past_title': {'ko': '확정된 라운드', 'en': 'Confirmed rounds'},
  'ag_past_unit': {'ko': '개', 'en': ''},
  'ag_past_hint': {
    'ko': '지난 라운드 배치입니다. 제목을 눌러 펼치거나 접습니다.',
    'en': 'Past round lineups. Tap a title to expand or collapse.',
  },
  'ag_past_round_suf': {'ko': 'R 배치', 'en': ' lineup'},

  // 명단
  'ag_roster': {'ko': '명단', 'en': 'Roster'},
  'ag_roster_total': {'ko': '전체', 'en': 'total'},
  'ag_roster_empty': {
    'ko': '아직 명단이 없습니다. 아래에서 사람을 추가하세요.',
    'en': 'No players yet. Add someone below.',
  },
  'ag_add_person': {'ko': '사람 추가', 'en': 'Add player'},
  'ag_name_ph': {'ko': '이름', 'en': 'Name'},
  'ag_add_btn': {'ko': '추가', 'en': 'Add'},
  'ag_add_hint': {
    'ko':
        '자리를 고르고 추가하세요. 처음 고른 자리가 주가 됩니다. 안 고르면 세터(S) 하나로 시작해요 — 추가 후 칩을 눌러 바꾸세요.',
    'en':
        'Pick positions and add. Your first pick is the main. If none, starts with Setter (S) — change it later by tapping the chips.',
  },
  'ag_tier_main': {'ko': '주', 'en': 'Main'},
  'ag_tier_sub': {'ko': '가능', 'en': 'Can'},
  'ag_tier_want': {'ko': '도전', 'en': 'Want'},
  'ag_set_main': {'ko': '주 포지션으로', 'en': 'Set as main'},
  'ag_tier_hint': {
    'ko':
        '처음 고른 자리가 주 포지션이에요. 더 누르면 가능 → 도전 → 해제로 바뀌고, ☆를 누르면 주 포지션을 바꿉니다. 경쟁 게임은 주만 씁니다.',
    'en':
        'Your first pick is your Main. Tap again for Can → Want → off; tap ☆ to change your main. Competitive games use Main only.',
  },
  'ag_bulk': {'ko': '일괄', 'en': 'Bulk'},
  'ag_all_on': {'ko': '전원 참석', 'en': 'All present'},
  'ag_all_off': {'ko': '전원 해제', 'en': 'All out'},
  'ag_to_default': {'ko': '명단 비우기', 'en': 'Clear roster'},
  'ag_clear_confirm': {
    'ko': '명단을 전부 비웁니다. 계속할까요?',
    'en': 'This clears the whole roster. Continue?',
  },
  'ag_del_confirm': {
    'ko': '{name} 님을 명단에서 지울까요?',
    'en': '{name} — remove from roster?',
  },
  'ag_dup_name': {
    'ko': '같은 이름이 이미 있습니다. 다른 사람으로 추가할까요?',
    'en': 'That name already exists. Add as a different person?',
  },
  'ag_leave_title': {'ko': '퇴장 시간', 'en': 'Leave time'},
  'ag_leave_none': {'ko': '끝까지', 'en': 'Stays'},

  // 기록
  'ag_record_title': {'ko': '누적 기록', 'en': 'Cumulative record'},
  'ag_th_name': {'ko': '이름', 'en': 'Name'},
  'ag_th_play': {'ko': '출전', 'en': 'Played'},
  'ag_th_bench': {'ko': '대기', 'en': 'Bench'},
  'ag_rounds_confirmed': {'ko': '{n}개 라운드 확정', 'en': '{n} rounds confirmed'},
  'ag_stat_empty': {
    'ko': '아직 확정한 라운드가 없습니다. 배치를 뽑고 확정을 누르면 여기에 쌓입니다.',
    'en':
        'No rounds confirmed yet. Draw a lineup and hit Confirm to log it here.',
  },
  'ag_stat_hint': {
    'ko': '이 기록을 보고 다음 라운드에서 출전 · 대기 · 포지션을 고르게 나눕니다.',
    'en':
        'This record spreads play, bench, and positions evenly across next rounds.',
  },
  'ag_reset_title': {'ko': '초기화', 'en': 'Reset'},
  'ag_reset_btn': {'ko': '기록 지우기', 'en': 'Clear record'},
  'ag_reset_hint': {
    'ko': '다음 모임을 시작할 때 눌러주세요. 명단은 남습니다.',
    'en': 'Hit this when starting the next meetup. The roster stays.',
  },
  'ag_reset_confirm': {
    'ko': '누적 기록을 지우고 1R부터 다시 시작합니다.',
    'en': 'Clear the cumulative record and restart from R1.',
  },

  // 포지션 이름
  'ag_pos_S': {'ko': '세터', 'en': 'Setter'},
  'ag_pos_OP': {'ko': '라이트', 'en': 'Opposite'},
  'ag_pos_OH': {'ko': '레프트', 'en': 'Outside'},
  'ag_pos_MB': {'ko': '센터', 'en': 'Middle'},
  'ag_pos_Li': {'ko': '리베로', 'en': 'Libero'},

  // 진단 (뽑기 불가 사유)
  'ag_dg_short': {
    'ko': '지금 설정으로는 한 경기에 {mc}명이 필요합니다. 참석 {n}명 — {gap}명 부족합니다.',
    'en':
        'This setup needs {mc} on court per game. Present: {n} — {gap} short.',
  },
  'ag_dg_only': {
    'ko':
        '{pos}({posko}) 전용이 {cnt}명({names})인데, 코트에 {pos} 자리는 최대 {max}개이고 대기는 {bench}명뿐입니다.',
    'en':
        '{cnt} players are {pos}-only ({names}), but there are at most {max} {pos} slots on court and only {bench} bench spots.',
  },
  'ag_dg_few': {
    'ko': '{pos}({posko})를 볼 수 있는 사람이 {able}명뿐입니다. 한 경기에 최소 {min}명이 필요합니다.',
    'en': 'Only {able} players can play {pos}. Each game needs at least {min}.',
  },
  'ag_dg_abc': {
    'ko':
        'A · B · C 모드는 팀 인원의 2배 이상 3배 이하일 때만 됩니다. {ranges}명 — 지금 {n}명입니다. 자유 편성으로 바꾸거나 팀 구성을 조정해 주세요.',
    'en':
        'A · B · C mode needs attendance 2× to 3× a team size. {ranges} — currently {n}. Switch to Free draft or adjust the team format.',
  },
  'ag_dg_generic': {
    'ko': '포지션 조합이 맞아떨어지지 않습니다. 가능 포지션을 늘리거나 팀 구성 · 인원을 조정해 주세요.',
    'en':
        "The position mix doesn't work out. Add more eligible positions, or adjust team format / headcount.",
  },

  // 설명 탭
  'ag_help_h1': {'ko': '배치가 정해지는 순서', 'en': 'How lineups are decided'},
  'ag_help_1a': {
    'ko': '참석자 중 경기가 끝나기 전에 퇴장하는 사람을 그 경기에서 뺍니다.',
    'en':
        'Among attendees, anyone leaving before a game ends is removed from it.',
  },
  'ag_help_1b': {
    'ko':
        'A · B · C 고정 — 라운드 시작에 세 팀 코어를 정합니다. A · B는 팀 인원만큼 꽉 채우고 남는 사람이 C 코어가 됩니다. 경기는 A vs B → B vs C → C vs A 순서이고, 코어는 자기 팀 경기에 반드시 출전합니다. 모자란 자리는 그 경기에 안 뛰는 팀에서 차출합니다.',
    'en':
        'A · B · C fixed — three team cores are set at round start. A · B fill up to team size, the rest become the C core. Games run A vs B → B vs C → C vs A, and cores always play their own team\'s game. Missing spots are borrowed from the team sitting out.',
  },
  'ag_help_1c': {
    'ko': '자유 편성 — 경기마다 참석자 전원 중에서 두 팀을 새로 짭니다.',
    'en':
        'Free draft — two fresh teams are drafted from all attendees each game.',
  },
  'ag_help_1d': {
    'ko':
        '모든 자리가 그 사람의 가능 포지션 안이어야 하고, 팀마다 세터 1명 · 대각(S↔OP, OH↔OH, MB↔Li) 구성을 만족해야 합니다.',
    'en':
        'Every slot must be within a player\'s eligible positions, and each team needs one setter with a valid diagonal (S↔OP, OH↔OH, MB↔Li).',
  },
  'ag_help_1e': {
    'ko': '조건을 만족하는 배치를 여러 개 뽑아 아래 공정성 점수가 가장 좋은 것을 고릅니다.',
    'en':
        'Several valid lineups are drawn and the one with the best fairness score below is chosen.',
  },
  'ag_help_h2': {
    'ko': '누가 먼저 뛰나 (공정성 점수)',
    'en': 'Who plays first (fairness score)',
  },
  'ag_help_2intro': {
    'ko': '점수가 낮은 사람이 먼저 코트에 들어갑니다. 확정한 라운드의 누적 기록과 이번 라운드 안의 기록을 합쳐서 봅니다.',
    'en':
        'Lower score goes on court first. It combines the confirmed cumulative record with what\'s happened within this round.',
  },
  'ag_help_2a': {'ko': '출전 횟수가 적을수록 먼저.', 'en': 'Fewer games played → sooner.'},
  'ag_help_2b': {
    'ko': '대기 횟수가 많을수록 먼저. 연속 대기는 벌점이 큽니다.',
    'en':
        'More times benched → sooner. Consecutive benching is penalized heavily.',
  },
  'ag_help_2c': {
    'ko':
        '가능 포지션이 적은 사람이 먼저. 세터만 되는 사람은 세터 자리에 우선 들어갑니다. 그래야 그 사람이 대기로 밀리지 않습니다.',
    'en':
        'Fewer eligible positions → sooner. Setter-only players get the setter slot first, so they don\'t get benched.',
  },
  'ag_help_2d': {
    'ko':
        '같은 포지션 반복은 피합니다. 단, 포지션을 고를 수 있는 사람에게만 적용되고, 한 포지션만 되는 사람은 반복해도 벌점이 없습니다.',
    'en':
        'Repeating the same position is avoided — but only for players who can pick; single-position players get no penalty for repeating.',
  },
  'ag_help_2e': {
    'ko': '운동 종료 전에 가는 사람은 있는 동안 거의 무조건 출전합니다. 어차피 뒤 경기를 못 뛰기 때문입니다.',
    'en':
        'Players leaving before session end play almost every game while present, since they can\'t play later ones.',
  },
  'ag_help_h3': {'ko': '자주 묻는 것', 'en': 'FAQ'},
  'ag_help_q1': {
    'ko': '세터 전용이 있으면 다른 사람 S를 꺼야 하나?',
    'en': 'If there\'s a setter-only player, should I turn off S for others?',
  },
  'ag_help_a1': {
    'ko':
        '아니요. 세터 전용이 있으면 어차피 그 사람이 세터 자리를 먼저 가져갑니다. S를 켜둬야 세터 전용이 대기 중이거나 일찍 갔을 때 대신 들어갈 수 있습니다.',
    'en':
        'No. A setter-only player takes the setter slot first anyway. Keep S on so someone can cover when that setter is benched or has left.',
  },
  'ag_help_q2': {
    'ko': 'A · B · C 모드가 안 만들어져요.',
    'en': 'A · B · C mode won\'t build.',
  },
  'ag_help_a2': {
    'ko':
        '참석 인원이 팀 인원의 2배~3배 사이여야 합니다 (6인 팀 12~18명, 7인 팀 14~21명). 인원이 맞는데도 안 되면 특정 포지션 전용 인원이 코트 자리보다 많은 경우입니다. 에러 안내를 확인하거나 자유 편성으로 바꿔 보세요.',
    'en':
        'Attendance must be 2×–3× a team size (6-team: 12–18, 7-team: 14–21). If the count fits but it still fails, some position-only group outnumbers the court slots. Check the error note or switch to Free draft.',
  },
  'ag_help_q3': {'ko': 'C 코어가 없다고 나와요.', 'en': 'It says there\'s no C core.'},
  'ag_help_a3': {
    'ko':
        '참석이 팀 인원의 정확히 2배일 때입니다. C는 전원 차출이라 세 경기 모두 같은 두 팀이 붙습니다. 상대를 섞으려면 자유 편성을 쓰세요.',
    'en':
        'That\'s when attendance is exactly 2× a team size. C is fully borrowed, so all three games pit the same two teams. Use Free draft to mix opponents.',
  },
  'ag_help_q4': {'ko': '확정은 언제 누르나?', 'en': 'When do I hit Confirm?'},
  'ag_help_a4': {
    'ko':
        '그 라운드를 실제로 뛰고 나서요. 확정해야 기록에 쌓이고 다음 라운드 공정성에 반영됩니다. 마음에 안 들면 확정 전에 다시 뽑으면 됩니다.',
    'en':
        'After actually playing that round. Confirming logs it and feeds next round\'s fairness. Not happy? Redraw before confirming.',
  },
};
