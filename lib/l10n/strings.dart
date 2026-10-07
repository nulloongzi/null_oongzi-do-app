// strings.dart — 한/영 문자열 사전. 웹 i18n.js 딕셔너리 포팅(주요 화면).
// 등록 폼은 한국어 유지(개설자 대상). 소비 동선(둘러보기·상세·공유·프로필·도시락)은 한/영.
const Map<String, Map<String, String>> kStrings = {
  // 공통
  // 영어 이름은 Nulloongzi-do 하나(웹 brand 와 같음)
  'brand': {'ko': '누룽지도', 'en': 'Nulloongzi-do'},
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
  'login_cancelled': {'ko': '로그인을 취소했어요', 'en': 'Login cancelled'},
  'login_kakao_fail': {
    'ko': '카카오로 로그인하지 못했어요. 잠시 후 다시 해 주세요.',
    'en': "Couldn't sign in with Kakao. Please try again in a moment.",
  },
  'login_naver_fail': {
    'ko': '네이버로 로그인하지 못했어요. 잠시 후 다시 해 주세요.',
    'en': "Couldn't sign in with Naver. Please try again in a moment.",
  },

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
  'data_load_err': {
    'ko': '팀 정보를 불러오지 못했어요. 인터넷 연결을 확인해 주세요.',
    'en': "Couldn't load teams. Check your internet connection.",
  },
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
  // 목록 시트 안 상세 모드의 뒤로가기(웹 pk_back_to_list 대응)
  'pk_back_to_list': {'ko': '← 목록으로', 'en': '← Back to list'},
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
    'ko': '애매하면 낮은 쪽을 골라 주세요. 남과 비교하지 말고 설명 기준으로요.',
    'en':
        'When in doubt, pick the lower level. Judge by the description, not by other players.',
  },
  'beginner_ok': {'ko': '🌱 초보환영', 'en': '🌱 Beginners'},
  'english_ok': {'ko': '🌐 English OK', 'en': '🌐 English OK'},

  // 상세
  'this_week': {'ko': '이번주', 'en': 'This week'},
  'urgent': {'ko': '🔥 게스트 급구', 'en': '🔥 Guests needed'},
  'chat_join': {'ko': '💬 단톡 들어가기', 'en': '💬 Join chat'},
  'share_btn': {'ko': '📤 공유하기', 'en': '📤 Share'},
  'bookmark_btn': {'ko': '🍱 도시락에 담기', 'en': '🍱 Add to lunchbox'},
  'insta_btn': {'ko': '📷 인스타', 'en': '📷 Instagram'},
  'home_btn': {'ko': '🔗 홈페이지', 'en': '🔗 Website'},
  'directions_btn': {'ko': '🚀 길찾기', 'en': '🚀 Directions'},
  'verify_btn': {'ko': '인증 신청 (사진 제출)', 'en': 'Apply for verification'},
  'verify_done': {
    'ko': '인증 신청을 받았어요.\n운영자가 확인하면 인증 배지가 붙어요.',
    'en': 'Verification request received.\nA badge is added after review.',
  },
  'vf_login_required': {
    'ko': '인증 신청은 로그인하면 할 수 있어요',
    'en': 'Log in to request verification.',
  },
  'vf_error': {
    'ko': '인증 신청을 보내지 못했어요. 잠시 후 다시 해 주세요.',
    'en': "Couldn't send the request. Please try again in a moment.",
  },
  'vf_submitting': {'ko': '사진 올리는 중…', 'en': 'Uploading photo…'},
  'vf_pending': {
    'ko': '⏳ 인증을 확인하고 있어요. 운영자가 확인하면 인증 배지가 붙어요.',
    'en': '⏳ Verification under review. A badge is added after review.',
  },
  'vf_rejected': {
    'ko': '❌ 인증이 받아들여지지 않았어요',
    'en': '❌ Verification was not accepted',
  },
  'vf_reason': {'ko': '사유: ', 'en': 'Reason: '},
  'vf_no_reason': {'ko': '적힌 사유가 없어요.', 'en': 'No reason given.'},
  'vf_reapply': {'ko': '🔄 인증 재신청', 'en': '🔄 Re-apply'},
  'urgent_on': {'ko': '🔥 게스트 급구 올리기', 'en': '🔥 Post a guest call'},
  'urgent_off': {'ko': '게스트 급구 내리기', 'en': 'End guest call'},
  'urgent_msg_hint': {
    'ko': '예: 이번주 토 세터 1명 급구!',
    'en': 'e.g. Need 1 setter this Sat!',
  },
  'modify_delete_body': {'ko': '지우면 되돌릴 수 없어요.', 'en': "This can't be undone."},
  'cd_delete_confirm': {'ko': '[{name}] 팀을 지울까요?', 'en': 'Delete [{name}]?'},
  'cd_delete_btn': {'ko': '팀 지우기', 'en': 'Delete team'},
  'cd_delete_error': {
    'ko': '팀을 지우지 못했어요. 잠시 후 다시 해 주세요.',
    'en': "Couldn't delete the team. Please try again in a moment.",
  },
  'pk_delete_confirm': {
    'ko': '이 게임을 지울까요? 참가자 정보도 함께 사라져요.',
    'en': 'Delete this game? Player info will be removed too.',
  },
  'pk_delete_btn': {'ko': '게임 지우기', 'en': 'Delete game'},
  'pk_delete_error': {
    'ko': '게임을 지우지 못했어요. 잠시 후 다시 해 주세요.',
    'en': "Couldn't delete the game. Please try again in a moment.",
  },
  'cd_urgent_btn': {'ko': '급구 올리기', 'en': 'Post'},
  'cd_update_error': {
    'ko': '바꾸지 못했어요. 잠시 후 다시 해 주세요.',
    'en': "Couldn't save the change. Please try again in a moment.",
  },
  'cd_urgent_posted': {'ko': '🔥 게스트 급구를 올렸어요', 'en': '🔥 Guest call posted'},
  'cd_urgent_closed': {'ko': '게스트 급구를 마감했어요', 'en': 'Guest call closed'},

  // 급구 — 운동 한 회차에 묶어 올리고, 그 운동이 끝나면 내려간다(서버 postUrgent).
  // 웹 js/i18n.js 와 키·문구가 같다(급구·회원 모집 계약).
  'ug_when': {
    'ko': '언제 운동에 필요해요?',
    'en': 'Which session do you need people for?',
  },
  'ug_other_day': {'ko': '다른 날', 'en': 'Another day'},
  'ug_end_time': {'ko': '끝나는 시각', 'en': 'End time'},
  'ug_msg_label': {'ko': '어떤 사람이 필요해요?', 'en': 'Who do you need?'},
  'ug_msg_hint': {
    'ko': '예: 센터 1명, 여자 레프트 1명',
    'en': 'e.g. 1 middle blocker, 1 female outside hitter',
  },
  'ug_auto_off': {
    'ko': '고른 운동이 끝나면 자동으로 내려가요',
    'en': 'It comes down automatically when that session ends.',
  },
  'ug_submit': {'ko': '급구 올리기', 'en': 'Post'},
  'ug_edit': {'ko': '게스트 급구 수정', 'en': 'Edit guest call'},
  'ug_err_unverified': {
    'ko': '인증된 팀만 급구를 올릴 수 있어요',
    'en': 'Only verified teams can post urgent calls.',
  },
  'ug_err_past': {
    'ko': '이미 지난 시간이에요. 다른 운동을 골라 주세요',
    'en': 'That time has passed. Pick another session.',
  },
  'ug_err_too_far': {
    'ko': '급구는 7일 안의 운동만 올릴 수 있어요',
    'en': 'Urgent calls are only for sessions within 7 days.',
  },
  'ug_err_msg_empty': {'ko': '어떤 사람이 필요한지 적어 주세요', 'en': 'Say who you need.'},
  'ug_err_msg_too_long': {'ko': '60자까지 쓸 수 있어요', 'en': 'Up to 60 characters.'},
  'ug_err_msg_link': {
    'ko': '링크는 넣을 수 없어요. 연락은 팀 연락처로 받아요',
    'en':
        "Links aren't allowed. People will reach you through the team contact.",
  },
  'ug_err_msg_phone': {
    'ko': '전화번호는 넣을 수 없어요. 연락은 팀 연락처로 받아요',
    'en':
        "Phone numbers aren't allowed. People will reach you through the team contact.",
  },
  'ug_err_not_manager': {
    'ko': '이 팀 관리자만 급구를 올릴 수 있어요',
    'en': "Only this team's admins can post urgent calls.",
  },
  'ug_err_blocked': {
    'ko': '이 팀은 지금 급구를 올릴 수 없어요. 운영자에게 문의해 주세요',
    'en': "This team can't post urgent calls right now. Please contact us.",
  },
  'ug_err_generic': {
    'ko': '급구를 올리지 못했어요. 잠시 후 다시 해 주세요',
    'en': "Couldn't post the urgent call. Please try again in a moment.",
  },
  'ug_until_today': {'ko': '오늘 {time}까지', 'en': 'Until {time} today'},
  'ug_until_tomorrow': {'ko': '내일 {time}까지', 'en': 'Until {time} tomorrow'},
  'ug_until_day': {
    'ko': 'D-{n} · {day} {time}까지',
    'en': 'D-{n} · until {day} {time}',
  },
  'ug_filter': {'ko': '🔥 게스트 급구만', 'en': '🔥 Guest calls only'},

  // 🍚 식구 모집(식구 = 같이 밥 먹는 사람 = 회원) — 급구와 따로, 인증 여부와 상관없이
  // 팀 관리자가 켠다. 🥄 맛보기 환영은 그 안의 선택(한 번 와서 뛰어 봐도 된다).
  // 웹 js/i18n.js 와 키·문구가 같다(식구 모집·여기 자리 있어요? 계약).
  'rc_badge': {'ko': '🍚 식구 모집', 'en': '🍚 Taking new members'},
  'rc_badge_desc': {
    'ko': '새 회원을 받고 있어요',
    'en': 'This team is taking new members.',
  },
  'rc_on': {'ko': '🍚 식구 모집 시작', 'en': '🍚 Start taking members'},
  'rc_off': {'ko': '식구 모집 마감', 'en': 'Stop taking members'},
  'rc_edit': {'ko': '식구 모집 수정', 'en': 'Edit'},
  'rc_msg_label': {
    'ko': '어떤 식구를 찾나요? (선택)',
    'en': 'Who are you looking for? (optional)',
  },
  'rc_msg_hint': {
    'ko': '예: 20~30대 여성 회원 모집해요',
    'en': 'e.g. Looking for women in their 20s–30s',
  },
  'rc_drop_in': {'ko': '🥄 맛보기 환영', 'en': '🥄 Drop-ins welcome'},
  'rc_drop_in_desc': {
    'ko': '한 번 와서 같이 뛰어 봐도 돼요',
    'en': 'You can come and play once to try it out.',
  },
  'rc_drop_in_ask': {
    'ko': '맛보기(체험·게스트)도 받아요',
    'en': 'We also welcome drop-ins (try-outs and guests)',
  },
  'rc_save': {'ko': '저장하기', 'en': 'Save'},
  'rc_saved': {'ko': '🍚 식구 모집을 올렸어요', 'en': '🍚 Now taking new members'},
  'rc_closed': {'ko': '식구 모집을 마감했어요', 'en': 'Stopped taking members'},
  'rc_auto_off': {
    'ko': '60일 동안 팀 정보를 고치지 않으면 자동으로 꺼져요',
    'en': 'Turns off automatically after 60 days without team updates.',
  },
  'rc_filter': {'ko': '🍚 식구 모집', 'en': '🍚 Taking members'},
  'ug_badge_desc': {
    'ko': '이번 운동에 같이 뛸 사람을 급하게 찾아요',
    'en': 'Looking for players for this session.',
  },

  // 🍚 여기 자리 있어요?(처음 이름 '이번 주 차림표') — 7일 안에 가서 뛸 수 있는 곳
  // (픽업 + 게스트 급구 + 맛보기 환영 팀의 운동). 키는 tw_* 그대로.
  'tw_entry': {
    'ko': '🍚 여기 자리 있어요? · {n}곳',
    'en': '🍚 Room for one more? · {n}',
  },
  'tw_title': {'ko': '🍚 여기 자리 있어요?', 'en': '🍚 Room for one more?'},
  'tw_sub': {
    'ko': '이번 주에 가서 뛸 수 있는 곳',
    'en': 'Places you can go and play this week',
  },
  'tw_empty': {'ko': '고른 조건에 맞는 곳이 아직 없어요', 'en': 'Nothing matches yet.'},
  'tw_kind_guest': {'ko': '🔥 게스트 급구', 'en': '🔥 Guests needed'},
  'tw_kind_drop_in': {'ko': '🥄 맛보기', 'en': '🥄 Drop-in'},
  'tw_kind_pickup': {'ko': '픽업', 'en': 'Pickup'},
  'tw_all_days': {'ko': '7일 전체', 'en': 'All 7 days'},
  'tw_contact': {'ko': '연락하기', 'en': 'Contact'},
  'tw_until': {'ko': '~{time}', 'en': 'until {time}'},

  // 공유 메뉴
  'share_title': {'ko': '공유하기', 'en': 'Share'},
  'share_story': {'ko': '📸 인스타 스토리', 'en': '📸 Instagram Story'},
  'share_feed': {'ko': '🖼 피드 이미지 (3:4)', 'en': '🖼 Feed image (3:4)'},
  'share_story_hint': {
    'ko': '링크 자동 복사 — 보는 사람은 탭 1번에 입장',
    'en': 'Link auto-copied — 1 tap to open',
  },
  'share_copy': {'ko': '🔗 링크 복사', 'en': '🔗 Copy link'},
  'share_more': {'ko': '📤 다른 앱으로 공유', 'en': '📤 Share to other apps'},
  'link_copied': {'ko': '링크를 복사했어요', 'en': 'Link copied'},
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
  // 포장하기 공유 버튼: 인스타 스토리 직행 · 다른 앱(OS 공유시트 — 카톡·저장)
  'mycard_share_story': {'ko': '인스타 스토리로 공유', 'en': 'Share to Instagram Story'},
  'mycard_share_other': {'ko': '다른 앱', 'en': 'Other apps'},
  'share_wrap': {'ko': '🎁 포장하기', 'en': '🎁 Wrap it up'},
  'change_nickname': {'ko': '이름 바꾸기', 'en': 'Change your name'},
  'logout': {'ko': '로그아웃', 'en': 'Log out'},
  'joined': {'ko': '가입', 'en': 'Joined'},
  'nickname_hint': {'ko': '새 이름 (하이픈 - 없이)', 'en': 'New name (no hyphen)'},
  'nickname_hyphen': {
    'ko': "이름에 하이픈(-)은 쓸 수 없어요. 하이픈은 '밥아저씨'가 지어 준 이름에만 들어가요",
    'en':
        "Names can't include a hyphen (-). Only auto-generated rice names have one.",
  },
  'nickname_dup': {
    'ko': '이미 누가 쓰고 있는 이름이에요',
    'en': 'Someone is already using that name.',
  },
  'nickname_done': {'ko': '이름을 바꿨어요', 'en': 'Name updated'},
  'nick_btn': {'ko': '바꾸기', 'en': 'Change'},
  'nick_empty': {'ko': '새 이름을 적어 주세요', 'en': 'Enter a new name.'},
  'nick_change_error': {
    'ko': '이름을 바꾸지 못했어요. 잠시 후 다시 해 주세요.',
    'en': "Couldn't change your name. Please try again in a moment.",
  },
  'nickname_reserved': {
    'ko': '누룽지도 공식 계정만 쓸 수 있는 이름이에요. 다른 이름을 골라 주세요.',
    'en':
        'That name is reserved for official Nulloongzi accounts. Please pick another.',
  },

  // 도시락
  'lunchbox_title': {'ko': '도시락 🍱', 'en': 'Lunchbox 🍱'},
  'lb_diet': {'ko': '📅 식단표 (스케줄 확인)', 'en': '📅 Weekly menu'},
  'lb_diet_collapse': {'ko': '📅 식단표 접기', 'en': '📅 Hide weekly menu'},
  'expand': {'ko': '펼치기', 'en': 'Expand'},
  'collapse': {'ko': '접기', 'en': 'Collapse'},
  'add_custom': {'ko': '커스텀 팀 추가', 'en': 'Add custom team'},
  'deleted_team': {'ko': '삭제된 팀', 'en': 'Deleted team'},
  'lb_full': {
    'ko': '도시락이 꽉 찼어요(5칸). 한 팀을 빼면 담을 수 있어요',
    'en': 'Your lunchbox is full (5). Take one out to add another.',
  },
  'lb_already': {'ko': '이미 도시락에 있어요', 'en': 'Already in your lunchbox'},
  'lb_added': {'ko': '도시락에 담았어요 🍱', 'en': 'Packed into your lunchbox 🍱'},
  'lb_added_custom': {
    'ko': '나만의 메뉴를 담았어요 🍙',
    'en': 'Packed into your menu 🍙',
  },
  'lb_add_title': {'ko': '🍙 직접 담기', 'en': '🍙 Pack your own'},
  'lb_add_name_label': {'ko': '팀·일정 이름', 'en': 'Team or session name'},
  'lb_add_time_label': {'ko': '시간', 'en': 'Time'},
  'lb_add_btn': {'ko': '도시락에 담기', 'en': 'Pack it'},
  'lb_add_name_empty': {'ko': '이름을 적어 주세요', 'en': 'Enter a name.'},
  'lb_add_time_empty': {
    'ko': '시간을 적어 주세요 (예: 월 19:00~21:00)',
    'en': 'Enter a time (e.g. 월 19:00~21:00).',
  },
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
  'insta_view': {'ko': 'Instagram에서 보기', 'en': 'View on Instagram'},
  'reels_more_label': {'ko': '릴스 더 보기', 'en': 'More reels'},
  'reels_hide': {'ko': '릴스 접기', 'en': 'Hide reels'},
  'reel_peek_hint': {
    'ko': '탭하면 인스타에서 보기 · 바깥을 누르면 닫기',
    'en': 'Tap to view on Instagram · tap outside to close',
  },
  'reel_peek_none': {
    'ko': '이 팀은 아직 릴스가 없어요',
    'en': 'No reel for this team yet',
  },
  'detail_pull_hint': {'ko': '▴ 위로 올려 시간표 보기', 'en': '▴ Pull up for schedule'},
  'detail_collapse_hint': {'ko': '▾ 접기', 'en': '▾ Collapse'},
  'lb_slot_rice': {'ko': '밥을\n담아 주세요🍚', 'en': 'Add rice 🍚'},
  'lb_slot_soup': {'ko': '국을\n담아 주세요🥘', 'en': 'Add soup 🥘'},
  'lb_slot_side1': {'ko': '반찬1🍳', 'en': 'Side 1 🍳'},
  'lb_slot_side2': {'ko': '반찬2🥗', 'en': 'Side 2 🥗'},
  'lb_slot_side3': {'ko': '반찬3🥢', 'en': 'Side 3 🥢'},
  'lb_save_err': {
    'ko': '도시락을 저장하지 못했어요. 잠시 후 다시 해 주세요.',
    'en': "Couldn't save your lunchbox. Please try again in a moment.",
  },
  'err_anon_auth': {
    'ko': '로그인하지 못했어요. 잠시 후 다시 해 주세요.',
    'en': "Couldn't log you in. Please try again in a moment.",
  },
  'sched_add': {'ko': '시간대 추가', 'en': 'Add time'},
  'map_pick_title': {'ko': '위치 선택', 'en': 'Pick location'},
  'map_pick_set': {'ko': '이 위치로 설정', 'en': 'Use this location'},
  'err_card': {
    'ko': '카드를 만들지 못했어요. 다시 해 주세요.',
    'en': "Couldn't make the card. Please try again.",
  },
  'err_share': {
    'ko': '공유하지 못했어요. 잠시 후 다시 해 주세요.',
    'en': "Couldn't share. Please try again in a moment.",
  },
  'back_exit_hint': {'ko': '한 번 더 누르면 종료돼요', 'en': 'Press back again to exit'},
  // 공유 카드(캔버스) 문구 — 웹 sh_club_fallback · sh_card_cta 와 같다. 이모지 금지(□로 깨짐).
  'card_title_fallback': {'ko': '배구 동호회', 'en': 'Volleyball club'},
  'card_cta': {
    'ko': 'QR 찍으면 누룽지도에서 열려요',
    'en': 'Scan to open in Nulloongzi-do',
  },
  'login_google_fail': {
    'ko': '구글로 로그인하지 못했어요. 잠시 후 다시 해 주세요.',
    'en': "Couldn't sign in with Google. Please try again in a moment.",
  },
  'login_err': {
    'ko': '로그인하지 못했어요. 잠시 후 다시 해 주세요.',
    'en': "Couldn't log you in. Please try again in a moment.",
  },
  'fab_lunchbox': {'ko': '도시락', 'en': 'Lunchbox'},
  'fab_profile': {'ko': '프로필', 'en': 'Profile'},
  'fab_register': {'ko': '등록', 'en': 'Register'},
  'fab_my_location': {'ko': '내 위치', 'en': 'My location'},
  'sheet_close': {'ko': '닫기', 'en': 'Close'}, // 시트 손잡이(화면 낭독기용 이름)
  'lb_add_name_hint': {'ko': '예: 우리 동호회', 'en': 'e.g. Our club'},
  'lb_add_sched_hint': {'ko': '토 14:00~17:00', 'en': 'Sat 14:00~17:00'},
  'lb_custom_team': {'ko': '커스텀 팀', 'en': 'Custom team'},
  'lb_remove': {'ko': '빼기', 'en': 'Take out'},
  'login_required': {'ko': '로그인하면 쓸 수 있어요', 'en': 'Log in to use this.'},
  'login_later': {'ko': '나중에 할게요 (둘러보기)', 'en': 'Maybe later (keep browsing)'},
  'pk_search_ph': {'ko': '픽업, 장소로 검색...', 'en': 'Search pickups or venues...'},
  // 검색·필터 결과 0 — 웹 i18n.js 와 같은 키
  'empty_result': {'ko': '조건에 맞는 팀이 없어요', 'en': 'No teams match'},
  'empty_result_reset': {'ko': '필터 지우기', 'en': 'Clear filters'},
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
    'ko': 'tip: 요일마다 체육관이 다르면 장소마다 따로 등록해 주세요. 그래야 지도 핀이 정확해요.',
    'en':
        'Tip: If your gym changes by day, register each location separately so the map pins are accurate.',
  },
  // 웹 reg_error/pk_create_err 대응 — 실패 원문 앞에 붙는 현지화 프리픽스
  'cf_save_err': {
    'ko': '팀을 저장하지 못했어요. 잠시 후 다시 해 주세요.',
    'en': "Couldn't save the team. Please try again in a moment.",
  },
  'pf_save_err': {
    'ko': '게임을 저장하지 못했어요. 잠시 후 다시 해 주세요.',
    'en': "Couldn't save the game. Please try again in a moment.",
  },
  'logout_confirm': {'ko': '로그아웃할까요?', 'en': 'Log out?'},
  'share_mode_card': {'ko': '네임카드', 'en': 'Name card'},
  'share_mode_diet': {'ko': '식단표', 'en': 'Schedule'},
  // 공유 카드(my_card.dart)는 Canvas에 직접 그려서 이모지가 tofu(□)로 뜬다.
  // 카드 안에 들어가는 문구는 이모지 없는 별도 키를 쓴다.
  'mycard_lunchbox': {'ko': '도시락', 'en': 'Lunchbox'},
  'mycard_timetable': {'ko': '식단표', 'en': 'Schedule'}, // 웹 mc_timetable 과 같은 말
  // 보온도시락 스택의 각 단 — 맨 아래 밥, 그 위 국, 맨 위 반찬 3칸.
  'mycard_tier_rice': {'ko': '밥', 'en': 'Rice'},
  'mycard_tier_soup': {'ko': '국', 'en': 'Soup'},
  'mycard_tier_sides': {'ko': '반찬', 'en': 'Sides'},
  'mycard_cta': {'ko': '나는 무슨 밥일까?', 'en': 'What rice are you?'},
  'mycard_cta_diet': {'ko': '같이 뛸 팀 찾기', 'en': 'Find a team to play with'},
  // 식단표 카드 헤드라인: "화·목·토 저녁형" · "주 3회 · 8시간 코트 위" (웹 mc_kind_* · mc_diet_*)
  'mycard_kind_eve': {'ko': '저녁형', 'en': 'evenings'},
  'mycard_kind_noon': {'ko': '낮형', 'en': 'afternoons'},
  'mycard_kind_morn': {'ko': '아침형', 'en': 'mornings'},
  'mycard_diet_ndays': {'ko': '주 {n}일', 'en': '{n} days a week ·'},
  'mycard_diet_sub': {
    'ko': '주 {n}회 · {h}시간 코트 위',
    'en': '{n} sessions · {h}h on court',
  },
  'mycard_diet_empty': {'ko': '이번 주 식단표', 'en': "This week's schedule"},
  // 밥도감(네임카드) — 웹 dex_* 와 같은 말. 단계 이름에 '누룽지'는 쓰지 않는다.
  'dex_no': {'ko': '밥도감 No.{n}', 'en': 'Rice-dex No.{n}'},
  'dex_r_common': {'ko': '흔함', 'en': 'Common'},
  'dex_r_rare': {'ko': '드묾', 'en': 'Rare'},
  'dex_r_legend': {'ko': '전설', 'en': 'Legendary'},
  'dex_title': {'ko': '내 밥상 · 밥도감', 'en': 'My table · Rice-dex'},
  'dex_count': {'ko': '{n} / {total}종', 'en': '{n} / {total} kinds'},
  'dex_next': {'ko': '{stage}까지 {n}종 남았어요', 'en': '{n} more to {stage}'},
  'dex_done': {'ko': '밥도감을 다 모았어요', 'en': 'Rice-dex complete'},
  'dex_st_1': {'ko': '혼밥', 'en': 'Solo meal'},
  'dex_st_2': {'ko': '밥상', 'en': 'A table'},
  'dex_st_3': {'ko': '한상차림', 'en': 'Full spread'},
  'dex_st_4': {'ko': '잔칫상', 'en': 'Feast'},
  'dex_st_5': {'ko': '수라상', 'en': 'Royal table'},
  // 밥 종류별 한 줄 성격 — 번호는 rice_dex.dart kRiceData 순서(= 밥도감 번호)
  'rice_line_1': {
    'ko': '씹을수록 진가가 나오는 꾸준파',
    'en': 'The steady one — better the more you chew',
  },
  'rice_line_2': {
    'ko': '어느 팀에 둬도 어울리는 기본기 장인',
    'en': 'Fits any team — master of the basics',
  },
  'rice_line_3': {
    'ko': '조용하다가 한 방에 색을 내는 타입',
    'en': 'Quiet, then one big splash of color',
  },
  'rice_line_4': {
    'ko': '소박하지만 든든한, 끝까지 뛰는 체력파',
    'en': 'Humble but hearty — runs till the end',
  },
  'rice_line_5': {
    'ko': '톡톡 튀는 존재감, 코트의 분위기 메이커',
    'en': 'Pops with presence — the mood maker',
  },
  'rice_line_6': {
    'ko': '뭐든 섞어도 맛있는 올라운더',
    'en': 'Mix in anything — the all-rounder',
  },
  'rice_line_7': {
    'ko': '작지만 꽉 찬, 수비에서 빛나는 알갱이',
    'en': 'Small but full — shines on defense',
  },
  'rice_line_8': {
    'ko': '알아보는 사람만 아는 은근한 실력파',
    'en': 'Quiet skill that only insiders notice',
  },
  'rice_line_9': {
    'ko': '경기 끝나고 제일 먼저 찾게 되는 편한 사람',
    'en': 'The comfy one everyone looks for after a game',
  },
  'rice_line_10': {'ko': '불 붙으면 못 말리는 화력형', 'en': 'Unstoppable once fired up'},
  'rice_line_11': {
    'ko': '섞일수록 팀워크가 사는 조율형',
    'en': 'Better mixed — the team-play conductor',
  },
  'rice_line_12': {
    'ko': '어디든 따라가는 원정 전문',
    'en': 'Goes anywhere — the away-game specialist',
  },
  'rice_line_13': {
    'ko': '부르면 바로 오는 기동력',
    'en': 'Call and they\'re already there',
  },
  'rice_line_14': {'ko': '달콤한 겉모습, 알찬 속', 'en': 'Sweet outside, packed inside'},
  'rice_line_15': {
    'ko': '한 그릇에 다 올리는 올인형',
    'en': 'Piles it all on — the all-in type',
  },
  'rice_line_16': {
    'ko': '믿고 맡기는 뜨끈한 해결사',
    'en': 'Warm and reliable — the problem solver',
  },
  'rice_line_17': {
    'ko': '시간이 걸려도 제대로 뜸 들이는 장인',
    'en': 'Takes time, but steamed just right',
  },
  'rice_line_18': {
    'ko': '팀을 챙기는 달달한 살림꾼',
    'en': 'Sweet devotion — looks after the team',
  },
  'rice_line_19': {
    'ko': '부드럽게 받아내는 리시브 장인',
    'en': 'Soft hands — the receive master',
  },
  'rice_line_20': {
    'ko': '한 번 보면 기억에 남는 사람',
    'en': 'Leaves a scent — hard to forget',
  },
  'rice_line_21': {
    'ko': '좋은 건 다 들어간 팀의 보약',
    'en': 'Everything good inside — the team\'s tonic',
  },
  'rice_line_22': {
    'ko': '마지막 한 점까지 긁어먹는 근성파',
    'en': 'Scrapes the last grain — pure grit',
  },
  'rice_line_23': {
    'ko': '3분이면 준비 완료, 번개 출석왕',
    'en': 'Ready in 3 minutes — first to every pickup',
  },
  'rice_line_24': {
    'ko': '푸짐한 열정, 연습량으로 승부',
    'en': 'A heaping bowl of passion — wins on practice',
  },
  'rice_line_25': {
    'ko': '참 쉽죠? 전설로만 전해지는 밥',
    'en': 'Happy little accidents — a living legend',
  },
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
  'f_addr_empty': {'ko': '주소를 적어 주세요', 'en': 'Enter an address.'},
  'f_addr_found': {'ko': '주소를 찾았어요!', 'en': 'Address found!'},
  'f_addr_notfound': {
    'ko': '이 주소로는 위치를 못 찾았어요. 도로명 주소로 적거나 지도에서 찍어 주세요',
    'en':
        "We couldn't find that address. Try a street address or pick it on the map.",
  },
  'f_pick_loc': {
    'ko': '지도에서 위치를 찍어 주세요',
    'en': 'Pick the location on the map.',
  },
  // 웹 reg_map_loc 대응 — 역지오코딩 실패 시 주소칸 기본 문구
  'f_map_loc': {'ko': '지도에서 선택된 위치', 'en': 'Location picked on map'},
  'f_link_invalid': {
    'ko': '링크는 http:// 나 https:// 로 시작해야 해요',
    'en': 'Links need to start with http:// or https://',
  },
  'cf_updated': {'ko': '팀 정보를 고쳤어요', 'en': 'Team info updated'},
  'pf_updated': {'ko': '게임 정보를 고쳤어요', 'en': 'Game updated'},
  'f_reel_invalid': {
    'ko': '인스타 공개 게시물/릴스 링크 형식이 아니에요. (예: https://www.instagram.com/reel/...)',
    'en':
        'That doesn’t look like a public Instagram post/reel link (e.g. https://www.instagram.com/reel/...).',
  },
  'cf_optional_summary': {
    'ko': '추가 정보 입력 (선택)',
    'en': 'Add more details (optional)',
  },
  'cf_field_required': {'ko': '필수', 'en': 'Required'},
  // 입력 칸 아래 오류(웹 js/field-error.js 와 같은 문구)
  'cf_err_name': {'ko': '팀 이름을 적어 주세요', 'en': 'Enter the team name.'},
  'cf_err_target': {
    'ko': '누구를 모집하는지 골라 주세요',
    'en': 'Pick who the team is for.',
  },
  'cf_err_addr': {'ko': '체육관 주소를 적어 주세요', 'en': 'Enter the gym address.'},
  'f_reel_label': {'ko': '릴스/게시물 링크 (선택)', 'en': 'Reel/post link (optional)'},
  'f_reel_hint': {
    'ko': '예: https://www.instagram.com/reel/...',
    'en': 'e.g. https://www.instagram.com/reel/...',
  },
  'reel_add': {'ko': '릴스 추가', 'en': 'Add reel'},
  'f_reel_too_many': {
    'ko': '릴스는 최대 {max}개까지 올릴 수 있어요',
    'en': 'You can add up to {max} reels',
  },
  'reels_hidden_notice': {
    'ko': '운영자가 이 릴스를 숨겼어요. 문의는 누룽지도 운영팀으로 해 주세요.',
    'en':
        'Reels were hidden by the moderators. Please contact the Nulloongzi-do team.',
  },
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
        '켜면 상세에 "공개 인스타 정보로 모은 크루" 안내와 수정/삭제 요청 링크가 보여요. 남의 크루를 대신 올릴 때만 켜 주세요.',
    'en':
        'Shows a "collected from public Instagram info" notice plus an edit/removal request link on the detail sheet. Only for crews you add on their behalf.',
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
  'pf_req': {'ko': '픽업 이름을 적어 주세요', 'en': 'Enter a name for the game.'},
  'pf_created': {'ko': '픽업 게임이 열렸어요! 🏐', 'en': 'Your pickup game is live! 🏐'},
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
  'cf_created': {
    'ko': '팀을 올렸어요! 이제 지도에서 보여요',
    'en': 'Your team is on the map!',
  },
  'cf_insta_invalid': {
    'ko': '인스타 아이디는 영문·숫자·밑줄(_)·점(.)으로 30자까지 적어 주세요 (@ 없이)',
    'en': 'Use letters, numbers, _ or . — up to 30, without @.',
  },
  'cf_name_max': {
    'ko': '팀 이름은 60자까지 쓸 수 있어요',
    'en': 'Team names can be up to 60 characters.',
  },
  'cf_target_max': {
    'ko': '대상은 80자까지 쓸 수 있어요',
    'en': "Who it's for can be up to 80 characters.",
  },
  'cf_addr_max': {
    'ko': '주소는 200자까지 쓸 수 있어요',
    'en': 'Addresses can be up to 200 characters.',
  },
  'cf_price_max': {
    'ko': '회비 설명은 100자까지 쓸 수 있어요',
    'en': 'Fee notes can be up to 100 characters.',
  },
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
    'ko': '온 사람을 솥에 안치듯 넣으면 라운드 배치가 나와요.',
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
  'ag_intro_s2': {'ko': '포지션을 골라 주세요', 'en': 'Pick their positions'},
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
    'ko': '실험 자리 = 주 포지션이 아닌 사람이 서는 자리. 이 수만큼만 열려요.',
    'en':
        'An open slot is one filled by someone off their main position. Only this many are allowed.',
  },
  'ag_tpl_title': {'ko': '팀 구성', 'en': 'Team format'},
  'ag_tpl_hint': {
    'ko': '(여러 개 고르면 그중에서 골라 써요)',
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
    'ko': '명단 탭에서 온 사람만 체크하고 뽑으세요. 마음에 안 들면 다시 뽑으면 돼요.',
    'en':
        'On the Roster tab, check who came, then draw. Not happy? Just redraw.',
  },
  'ag_again': {'ko': '다시 뽑기', 'en': 'Redraw'},
  'ag_confirm_next': {'ko': '확정 · 다음 라운드', 'en': 'Confirm · next round'},
  'ag_confirm_hint': {
    'ko': '확정하면 기록에 반영돼 다음 라운드에서 출전 · 대기 · 포지션이 더 고르게 분배돼요.',
    'en':
        'Confirming logs it, so play, bench, and positions spread more evenly next round.',
  },

  // 결과 안내
  'ag_ok_done': {'ko': '{r}R 배치 완료', 'en': 'Round {r} set'},
  'ag_ok_abc': {
    'ko': 'A · B · C 코어를 정하고 안 뛰는 팀에서 차출해 채웠어요. 차출 표시가 붙은 사람은 원래 다른 팀이에요.',
    'en':
        'Set A · B · C cores and filled gaps by borrowing from the team sitting out. Players marked borrowed belong to another team.',
  },
  'ag_ok_free': {
    'ko': '매 경기 두 팀을 새로 짰어요.',
    'en': 'Drafted two fresh teams for each game.',
  },
  'ag_relaxed': {
    'ko': '주 포지션만으로는 팀이 안 짜여서 실험 자리를 팀당 {n}개까지 열었어요.',
    'en':
        'Main positions alone could not fill the teams, so up to {n} open slot(s) per team were allowed.',
  },
  'ag_core_title': {'ko': '이번 라운드 코어', 'en': 'Cores this round'},
  'ag_core_none': {'ko': '없음 (전원 차출)', 'en': 'none (all borrowed)'},
  'ag_no_c_core': {
    'ko':
        '참석 인원이 팀 인원의 정확히 2배라 C 코어가 없어요. C는 안 뛰는 팀에서 전원 차출되므로 세 경기 모두 같은 두 팀이 붙어요. 경기마다 상대를 섞으려면 자유 편성으로 바꿔 주세요.',
    'en':
        'Attendance is exactly twice a team size, so there is no C core. C is fully borrowed from the sitting-out team, so all three games pit the same two teams. To mix opponents, switch to Free draft.',
  },
  'ag_infeasible': {
    'ko': '이 인원 · 설정으로는 배치를 만들 수 없어요.',
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
    'ko': '두 팀 자리 적합도가 비슷해요.',
    'en': 'Both teams sit at similar position fit.',
  },
  'ag_fitgap_off': {
    'ko': '한쪽 팀이 낯선 자리를 더 맡았어요.',
    'en': 'One team took more unfamiliar slots.',
  },

  // 과거 라운드
  'ag_past_title': {'ko': '확정된 라운드', 'en': 'Confirmed rounds'},
  'ag_past_unit': {'ko': '개', 'en': ''},
  'ag_past_hint': {
    'ko': '지난 라운드 배치예요. 제목을 눌러 펼치거나 접어요.',
    'en': 'Past round lineups. Tap a title to expand or collapse.',
  },
  'ag_past_round_suf': {'ko': 'R 배치', 'en': ' lineup'},

  // 명단
  'ag_roster': {'ko': '명단', 'en': 'Roster'},
  'ag_roster_total': {'ko': '전체', 'en': 'total'},
  'ag_roster_empty': {
    'ko': '아직 명단이 없어요. 아래에서 사람을 추가하세요.',
    'en': 'No players yet. Add someone below.',
  },
  'ag_add_person': {'ko': '사람 추가', 'en': 'Add player'},
  'ag_name_ph': {'ko': '이름', 'en': 'Name'},
  'ag_add_btn': {'ko': '추가', 'en': 'Add'},
  'ag_add_hint': {
    'ko':
        '자리를 고르고 추가하세요. 처음 고른 자리가 주가 돼요. 안 고르면 어디든 설 수 있는 사람으로 '
        '들어가요 — 나중에 칩을 눌러 정하면 돼요.',
    'en':
        'Pick seats and add. Your first pick is the main. Pick none and they join as able to '
        'play anywhere — set it later by tapping the chips.',
  },
  'ag_tier_main': {'ko': '주', 'en': 'Main'},
  'ag_tier_sub': {'ko': '가능', 'en': 'Can'},
  'ag_tier_want': {'ko': '도전', 'en': 'Want'},
  'ag_set_main': {'ko': '주 포지션으로', 'en': 'Set as main'},
  'ag_tier_hint': {
    'ko':
        '처음 고른 자리가 주 자리예요. 더 누르면 가능 → 도전 → 해제로 바뀌고, 길게 누르면 주 자리를 바꿔요. '
        '자리를 다 지우면 어디든 설 수 있는 사람이 돼요.',
    'en':
        'Your first pick is your Main. Tap again for Can → Want → off; long-press to change your '
        'main. Clear every seat and they can play anywhere.',
  },
  'ag_bulk': {'ko': '일괄', 'en': 'Bulk'},
  'ag_all_on': {'ko': '전원 참석', 'en': 'All present'},
  'ag_all_off': {'ko': '전원 해제', 'en': 'All out'},
  'ag_to_default': {'ko': '명단 비우기', 'en': 'Clear roster'},
  'ag_clear_confirm': {
    'ko': '명단을 전부 비워요. 계속할까요?',
    'en': 'This clears the whole roster. Continue?',
  },
  'ag_del_confirm': {
    'ko': '{name} 님을 명단에서 지울까요?',
    'en': '{name} — remove from roster?',
  },
  'ag_dup_name': {
    'ko': '같은 이름이 이미 있어요. 다른 사람으로 추가할까요?',
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
    'ko': '아직 확정한 라운드가 없어요. 배치를 뽑고 확정을 누르면 여기에 쌓여요.',
    'en':
        'No rounds confirmed yet. Draw a lineup and hit Confirm to log it here.',
  },
  'ag_stat_hint': {
    'ko': '이 기록을 보고 다음 라운드에서 출전 · 대기 · 포지션을 고르게 나눠요.',
    'en':
        'This record spreads play, bench, and positions evenly across next rounds.',
  },
  'ag_reset_title': {'ko': '초기화', 'en': 'Reset'},
  'ag_reset_btn': {'ko': '기록 지우기', 'en': 'Clear record'},
  'ag_reset_hint': {
    'ko': '다음 모임을 시작할 때 눌러 주세요. 명단은 남아요.',
    'en': 'Hit this when starting the next meetup. The roster stays.',
  },
  'ag_reset_confirm': {
    'ko': '누적 기록을 지우고 1R부터 다시 시작해요.',
    'en': 'Clear the cumulative record and restart from R1.',
  },

  // 포지션 이름
  'ag_pos_S': {'ko': '세터', 'en': 'Setter'},
  'ag_pos_OP': {'ko': '라이트', 'en': 'Opposite'},
  'ag_pos_OH': {'ko': '레프트', 'en': 'Outside'},
  'ag_pos_MB': {'ko': '센터', 'en': 'Middle'},
  'ag_pos_Li': {'ko': '리베로', 'en': 'Libero'},

  // 9인제 역할 — 명단에서는 이 여섯 가지만 고른다.
  'ag_pos_S9': {'ko': '세터', 'en': 'Setter'},
  'ag_pos_QK': {'ko': '속공', 'en': 'Quick'},
  'ag_pos_L9': {'ko': '레프트', 'en': 'Left'},
  'ag_pos_R9': {'ko': '라이트', 'en': 'Right'},
  'ag_pos_CH': {'ko': '차', 'en': 'Mid'},
  'ag_pos_BK': {'ko': '백', 'en': 'Back'},

  // 칩처럼 좁은 자리에 쓰는 짧은 이름(6인제는 코드가 이미 짧아 그대로).
  'ag_posx_S': {'ko': '세터', 'en': 'S'},
  'ag_posx_OP': {'ko': '라이트', 'en': 'OP'},
  'ag_posx_OH': {'ko': '레프트', 'en': 'OH'},
  'ag_posx_MB': {'ko': '센터', 'en': 'MB'},
  'ag_posx_Li': {'ko': '리베로', 'en': 'Li'},
  'ag_posx_S9': {'ko': '세터', 'en': 'Setter'},
  'ag_posx_QK': {'ko': '속공', 'en': 'Quick'},
  'ag_posx_L9': {'ko': '레프트', 'en': 'Left'},
  'ag_posx_R9': {'ko': '라이트', 'en': 'Right'},
  'ag_posx_CH': {'ko': '차', 'en': 'Mid'},
  'ag_posx_BK': {'ko': '백', 'en': 'Back'},

  // 9인제 자리 이름 — 포메이션마다 다르다(코트에만 표시).
  'ag_seat_s9': {'ko': '세터', 'en': 'Setter'},
  'ag_seat_qk': {'ko': '속공', 'en': 'Quick'},
  'ag_seat_fqk': {'ko': '앞속공', 'en': 'Front quick'},
  'ag_seat_bqk': {'ko': '빽속공', 'en': 'Back quick'},
  'ag_seat_qa': {'ko': '앞A', 'en': 'A quick'},
  'ag_seat_qb': {'ko': '앞B', 'en': 'B quick'},
  'ag_seat_b': {'ko': 'B', 'en': 'B'},
  'ag_seat_l9': {'ko': '레프트', 'en': 'Left'},
  'ag_seat_r9': {'ko': '라이트', 'en': 'Right'},
  'ag_seat_ch': {'ko': '차', 'en': 'Mid'},
  'ag_seat_fch': {'ko': '앞차', 'en': 'Front mid'},
  'ag_seat_bch': {'ko': '빽차', 'en': 'Back mid'},
  'ag_seat_lb': {'ko': '레프트백', 'en': 'Left back'},
  'ag_seat_cb': {'ko': '백센터', 'en': 'Back centre'},
  'ag_seat_cb2': {'ko': '센터백', 'en': 'Centre back'},
  'ag_seat_rb': {'ko': '라이트백', 'en': 'Right back'},
  'ag_seat_s_front': {'ko': '세터 · 라이트', 'en': 'Setter · right'},

  // 6인제 전술
  'ag_tactic_title': {'ko': '전술', 'en': 'System'},
  'ag_tactic_51': {'ko': '5-1', 'en': '5-1'},
  'ag_tactic_51_sub': {'ko': '세터 1명', 'en': 'one setter'},
  'ag_tactic_62': {'ko': '6-2', 'en': '6-2'},
  'ag_tactic_62_sub': {
    'ko': '세터 2명 · 전위는 라이트',
    'en': 'two setters · front one hits right',
  },
  'ag_tactic_hint': {
    'ko':
        '5-1 은 세터 한 명이 여섯 자리를 다 돌고, 6-2 는 세터 둘이 후위에서 번갈아 토스해요. '
        '6-2 의 전위 세터는 라이트 자리에서 공격해요.',
    'en':
        'In 5-1 one setter runs all six rotations; in 6-2 two setters take turns setting '
        'from the back row, and the front-row setter attacks from the right.',
  },

  // 9인제 포메이션
  'ag_form_title': {'ko': '포메이션', 'en': 'Formation'},
  'ag_form_hint': {
    'ko': '(속공 수에 따라 리시브 줄이 갈려요)',
    'en': '(the number of quicks decides the receive rows)',
  },
  'ag_tpl_q1': {'ko': '속공 1 · 2-4-3', 'en': '1 quick · 2-4-3'},
  'ag_tpl_q1_desc': {
    'ko': '앞 2 · 가운데 4 · 뒤 3',
    'en': 'front 2 · middle 4 · back 3',
  },
  'ag_tpl_q2': {'ko': '속공 2 · 3-4-2', 'en': '2 quicks · 3-4-2'},
  'ag_tpl_q2_desc': {
    'ko': '앞 3 · 가운데 4 · 뒤 2',
    'en': 'front 3 · middle 4 · back 2',
  },
  'ag_tpl_q3': {'ko': '속공 3 · 4-3-2', 'en': '3 quicks · 4-3-2'},
  'ag_tpl_q3_desc': {
    'ko': '앞 4 · 가운데 3 · 뒤 2',
    'en': 'front 4 · middle 3 · back 2',
  },
  'ag_note_q2': {
    'ko': '앞차 · 빽차 중 한 명은 수비 때 뒤로 빠져 가운데를 보고, 거기서 공격에 들어가요.',
    'en':
        'On defence one of the two mids drops back to cover the centre, and attacks from there.',
  },
  'ag_note_q3': {
    'ko': '차는 수비 때 뒤로 빠져 가운데를 보고, 거기서 공격에 들어가요.',
    'en':
        'On defence the mid drops back to cover the centre, and attacks from there.',
  },

  // 종목
  'ag_sport_title': {'ko': '종목', 'en': 'Format'},
  'ag_sport_v6': {'ko': '6인제', 'en': '6-a-side'},
  'ag_sport_v6_sub': {'ko': '로테이션 · 대각', 'en': 'rotation · diagonals'},
  'ag_sport_v9': {'ko': '9인제', 'en': '9-a-side'},
  'ag_sport_v9_sub': {'ko': '속공 수로 줄 구성', 'en': 'rows by quick count'},

  // 배치 우선순위
  'ag_prio_title': {'ko': '배치 우선순위', 'en': 'Lineup priority'},
  'ag_prio_custom': {'ko': '맞춘 자리 우선', 'en': 'Set seats first'},
  'ag_prio_custom_sub': {'ko': '고정 · 주 자리부터', 'en': 'pins · main seats'},
  'ag_prio_variety': {'ko': '다양성 우선', 'en': 'Variety first'},
  'ag_prio_variety_sub': {'ko': '안 해본 자리부터', 'en': 'unplayed seats first'},
  'ag_prio_hint': {
    'ko':
        '맞춘 자리 우선은 고정(📌)해 둔 자리와 각자 고른 주 자리를 먼저 지켜요. '
        '사람에게 등급을 매기는 게 아니라, 진행하는 사람이 자리를 직접 지정하는 거예요.',
    'en':
        '"Set seats first" keeps pinned (📌) seats and each player\'s main seat '
        'as much as possible. It is not a skill grade — the organizer picks the seats.',
  },
  'ag_adv_title': {'ko': '고급 설정', 'en': 'Advanced'},
  'ag_flex_title': {'ko': '실험 자리(팀당)', 'en': 'Open slots (per team)'},
  'ag_flex_hint': {
    'ko': '주 자리가 아닌 사람이 설 수 있는 자리 수예요. 0이면 전원 주 자리로만 짜요.',
    'en':
        'How many players may stand off their main seat. 0 means main seats only.',
  },

  // 고정(핀)
  'ag_pin_on_title': {'ko': '고정 해제', 'en': 'Unpin'},
  'ag_pin_off_title': {'ko': '주 자리로 고정', 'en': 'Pin to main seat'},
  'ag_pin_team_any': {'ko': '팀 자동', 'en': 'Auto'},
  'ag_pin_hint': {
    'ko':
        '📌 를 누르면 그 사람은 주 자리에만 서요. 옆 칸에서 A · B · C 코어도 지정할 수 있어요'
        '(A · B · C 고정 모드).',
    'en':
        'Tap 📌 and that player only takes their main seat. The box next to it '
        'pins them to an A · B · C core (A · B · C mode).',
  },
  'ag_pin_relaxed': {
    'ko': '고정(📌)을 전부 지키면 배치가 안 나와서, 이번 라운드는 고정을 풀고 짰어요.',
    'en':
        'Pins (📌) could not all be kept, so this round was drawn without them.',
  },

  // 빈 자리 · 인원 부족
  'ag_need_label': {'ko': '필요', 'en': 'needed'},
  'ag_needs_title': {'ko': '비는 자리', 'en': 'Open seats'},
  'ag_shortage_note': {
    'ko':
        '지금 인원으로는 자리가 비어요. 그래도 배치는 뽑고 빈 자리를 (필요)로 표시해요 — '
        '어떤 자리를 더 구해야 하는지 보이라고요.',
    'en':
        'There aren\'t enough players for every seat. The lineup is still drawn and '
        'empty seats are marked (needed), so you can see what to recruit.',
  },
  'ag_abc_fallback': {
    'ko': 'A · B · C 는 참석이 팀 인원의 2~3배일 때만 돼요. 이번 라운드는 자유 편성으로 짰어요.',
    'en':
        'A · B · C needs 2×–3× a team size. This round was drawn as a free draft instead.',
  },
  'ag_ok_done_need': {
    'ko': '채울 수 있는 자리는 다 채웠고, 사람이 없는 자리는 (필요)로 남겼어요.',
    'en': 'Every fillable seat is filled; the rest are left as (needed).',
  },

  // 명단
  'ag_flex_badge': {'ko': '어디든', 'en': 'anywhere'},
  'ag_flex_player_hint': {
    'ko': '자리를 하나도 안 고르면 어디든 설 수 있는 사람으로 봐요. 급할 땐 이름만 넣고 시작하세요.',
    'en':
        'A player with no seat picked is treated as able to play anywhere. '
        'In a hurry, just add names and go.',
  },
  'ag_bulk_add': {'ko': '여러 명 한 번에', 'en': 'Add several'},
  'ag_bulk_ph': {
    'ko': '이름을 줄바꿈이나 쉼표로 구분해 붙여넣기',
    'en': 'Paste names separated by new lines or commas',
  },
  'ag_bulk_btn': {'ko': '한 번에 추가', 'en': 'Add all'},
  'ag_bulk_added': {'ko': '{n}명 추가했어요.', 'en': 'Added {n}.'},

  // 보기 전환
  'ag_now_word': {'ko': '지금', 'en': 'now'},
  'ag_compact_court': {'ko': '코트', 'en': 'Court'},
  'ag_compact_list': {'ko': '간단히', 'en': 'Compact'},

  // 9인제 구성

  // 모임 보관 · 백업
  'ag_meet_title': {'ko': '지난 모임', 'en': 'Past meetups'},
  'ag_meet_none': {'ko': '보관한 모임이 없어요.', 'en': 'No meetups archived yet.'},
  'ag_meet_archive': {
    'ko': '이번 모임 보관하고 새로 시작',
    'en': 'Archive this meetup · start fresh',
  },
  'ag_meet_archive_confirm': {
    'ko': '이번 모임 기록을 보관하고 1R부터 새로 시작해요. 명단은 그대로 남아요.',
    'en':
        'Archive this meetup\'s record and restart from R1. The roster stays.',
  },
  'ag_meet_archive_empty': {
    'ko': '보관할 기록이 없어요. 라운드를 확정한 뒤에 눌러 주세요.',
    'en': 'Nothing to archive yet — confirm a round first.',
  },
  'ag_meet_rounds_suf': {'ko': '개 라운드', 'en': ' rounds'},
  'ag_meet_del_confirm': {
    'ko': '이 모임 기록을 지울까요?',
    'en': 'Delete this archived meetup?',
  },
  'ag_meet_hint': {
    'ko': '모임을 보관해 두면 누적 기록은 새로 시작하고, 지난 모임은 여기 남아요.',
    'en':
        'Archiving resets the cumulative record while keeping the meetup here.',
  },
  'ag_backup_title': {'ko': '백업', 'en': 'Backup'},
  'ag_backup_export': {'ko': '내보내기', 'en': 'Export'},
  'ag_backup_import': {'ko': '불러오기', 'en': 'Import'},
  'ag_backup_import_hint': {
    'ko': '내보낸 JSON 을 붙여넣으세요. 지금 명단 · 기록은 사라져요.',
    'en': 'Paste exported JSON. This replaces the current roster and record.',
  },
  'ag_backup_bad': {'ko': '읽을 수 없는 내용이에요.', 'en': 'Could not read that.'},
  'ag_backup_done': {'ko': '불러왔어요.', 'en': 'Imported.'},
  'ag_backup_hint': {
    'ko': '기기를 바꾸기 전에 내보내 두세요. 불러오면 지금 내용은 사라져요.',
    'en':
        'Export before switching devices. Importing replaces what you have now.',
  },
  'ag_cancel': {'ko': '취소', 'en': 'Cancel'},

  // 진단 (뽑기 불가 사유)
  'ag_dg_short': {
    'ko': '지금 설정으로는 한 경기에 {mc}명이 필요해요. 참석 {n}명 — {gap}명 부족해요.',
    'en':
        'This setup needs {mc} on court per game. Present: {n} — {gap} short.',
  },
  'ag_dg_only': {
    'ko':
        '{pos}({posko}) 전용이 {cnt}명({names})인데, 코트에 {pos} 자리는 최대 {max}개이고 대기는 {bench}명뿐이에요.',
    'en':
        '{cnt} players are {pos}-only ({names}), but there are at most {max} {pos} slots on court and only {bench} bench spots.',
  },
  'ag_dg_few': {
    'ko': '{pos}({posko})를 볼 수 있는 사람이 {able}명뿐이에요. 한 경기에 최소 {min}명이 필요해요.',
    'en': 'Only {able} players can play {pos}. Each game needs at least {min}.',
  },
  'ag_dg_abc': {
    'ko':
        'A · B · C 모드는 팀 인원의 2배 이상 3배 이하일 때만 돼요. {ranges}명 — 지금 {n}명이에요. 자유 편성으로 바꾸거나 팀 구성을 조정해 주세요.',
    'en':
        'A · B · C mode needs attendance 2× to 3× a team size. {ranges} — currently {n}. Switch to Free draft or adjust the team format.',
  },
  'ag_dg_generic': {
    'ko': '포지션 조합이 맞아떨어지지 않아요. 가능 포지션을 늘리거나 팀 구성 · 인원을 조정해 주세요.',
    'en':
        "The position mix doesn't work out. Add more eligible positions, or adjust team format / headcount.",
  },

  // 설명 탭
  'ag_help_h1': {'ko': '배치가 정해지는 순서', 'en': 'How lineups are decided'},
  'ag_help_1sport': {
    'ko':
        '먼저 종목을 골라요. 6인제는 로테이션이 있어 존(1~6)으로 서고, 5-1(세터 1) 과 '
        '6-2(세터 2 · 전위 세터는 라이트)로 갈려요. 9인제는 로테이션이 없고 속공 수로 '
        '리시브 줄이 갈려요 — 속공 1명이면 2-4-3, 2명이면 3-4-2, 3명이면 4-3-2. '
        '명단에서는 역할 6종(세터 · 속공 · 레프트 · 라이트 · 차 · 백)만 고르면 돼요.',
    'en':
        'Pick the format first. 6-a-side rotates through zones 1–6 and splits into 5-1 and 6-2; '
        '9-a-side does not rotate, and the number of quicks decides the receive rows.',
  },
  'ag_help_1pin': {
    'ko':
        '고정(📌)을 가장 먼저 지켜요. 고정한 사람은 주 자리에만 서고, 팀을 지정했으면 그 코어로 가요. '
        '다 지킬 수 없으면 고정을 풀고 뽑은 뒤 그 사실을 알려 줘요.',
    'en':
        'Pins (📌) are kept first: a pinned player only takes their main seat, and a pinned '
        'team sends them to that core. If they cannot all be kept, the round is drawn without them and says so.',
  },
  'ag_help_1need': {
    'ko':
        '인원이 모자라면 못 뽑는다고 막지 않고, 못 채운 자리를 (필요)로 비워 둬요 — '
        '어떤 자리를 더 구해야 하는지 보이라고요.',
    'en':
        'If there are not enough players, unfillable seats are left as (needed) instead of '
        'refusing to draw — so you can see what to recruit.',
  },
  'ag_help_h4': {
    'ko': '우선순위 — 맞춘 자리 vs 다양성',
    'en': 'Priority: set seats vs variety',
  },
  'ag_help_4a': {
    'ko':
        '맞춘 자리 우선은 고정과 각자 고른 주 자리를 지켜 게임이 매끄럽게 굴러가게 해요. '
        '다양성 우선은 아직 안 해본 자리를 먼저 나눠 줘요.',
    'en':
        '"Set seats first" keeps pins and each player\'s own main seat so games run smoothly. '
        '"Variety first" hands out seats people have not played yet.',
  },
  'ag_help_4b': {
    'ko':
        '둘 다 실력 등급이 아니에요. 주 · 가능 · 도전은 본인이 고르는 것이고, 고정은 진행하는 사람이 '
        '지정하는 거예요 — 사람에게 순위를 매기지 않아요.',
    'en':
        'Neither is a skill grade. Tiers are what each player picks for themselves, and pins are '
        'what the organizer sets — nobody is ranked.',
  },
  'ag_help_4c': {
    'ko':
        '실험 자리(고급 설정)는 팀당 몇 명까지 주 자리가 아닌 자리에 설 수 있는지예요. '
        '0이면 전원 주 자리로만 짜고, 그걸로 안 되면 자동으로 한 칸씩 열려요.',
    'en':
        'Open slots (Advanced) is how many players per team may stand off their main seat. '
        '0 means main seats only; it opens up automatically if a lineup is otherwise impossible.',
  },
  'ag_help_q5': {
    'ko': '인원이 모자라면 어떻게 돼요?',
    'en': 'Not enough people — what happens?',
  },
  'ag_help_a5': {
    'ko':
        '그래도 뽑아요. 못 채운 자리가 (필요)로 자리 이름과 함께 뜨니, 세터가 필요한지 센터가 '
        '필요한지 보고 단톡방에 올리면 돼요.',
    'en':
        'It still draws. Empty seats show as (needed) with the seat name, so you know what to '
        'ask the group chat for.',
  },
  'ag_help_q6': {'ko': '다음 모임은?', 'en': 'Next meetup?'},
  'ag_help_a6': {
    'ko':
        '기록 탭에서 이번 모임을 보관하면 누적 기록은 1R부터 다시 시작하고 지난 모임은 목록에 남아요. '
        '기기를 바꾸기 전에는 백업 내보내기를 하세요.',
    'en':
        'On the Record tab, archive this meetup: the cumulative record restarts while the meetup '
        'stays in the list. Export a backup before changing devices.',
  },
  'ag_help_1a': {
    'ko': '참석자 중 경기가 끝나기 전에 퇴장하는 사람을 그 경기에서 빼요.',
    'en':
        'Among attendees, anyone leaving before a game ends is removed from it.',
  },
  'ag_help_1b': {
    'ko':
        'A · B · C 고정 — 라운드 시작에 세 팀 코어를 정해요. 경기는 A vs B → B vs C → C vs A 순서이고, 코어는 자기 팀 경기에 반드시 출전해요. 모자란 자리는 안 뛰는 팀에서 차출해요. 참석이 팀 인원의 2~3배여야 하고, 그보다 적으면 자유 편성으로 내려가요.',
    'en':
        'A · B · C fixed — three team cores are set at round start. Games run A vs B → B vs C → C vs A, and cores always play their own team\'s game. Missing spots are borrowed from the team sitting out. It needs attendance of 2×–3× a team size; below that it falls back to a free draft.',
  },
  'ag_help_1c': {
    'ko': '자유 편성 — 경기마다 참석자 전원 중에서 두 팀을 새로 짜요.',
    'en':
        'Free draft — two fresh teams are drafted from all attendees each game.',
  },
  'ag_help_1d': {
    'ko':
        '모든 자리가 그 사람의 가능 자리 안이어야 해요. 6인제는 여기에 더해 팀마다 세터 1명 · '
        '대각(S↔OP, OH↔OH, MB↔Li)을 맞춰요. 자리를 하나도 안 고른 사람은 어디든 설 수 있는 사람으로 봐요.',
    'en':
        'Every seat must be within a player\'s eligible seats; 6-a-side also needs one setter per team with a valid diagonal (S↔OP, OH↔OH, MB↔Li). A player with no seat picked can play anywhere.',
  },
  'ag_help_1e': {
    'ko': '조건을 만족하는 배치를 여러 개 뽑아 아래 공정성 점수가 가장 좋은 것을 골라요.',
    'en':
        'Several valid lineups are drawn and the one with the best fairness score below is chosen.',
  },
  'ag_help_h2': {
    'ko': '누가 먼저 뛰나 (공정성 점수)',
    'en': 'Who plays first (fairness score)',
  },
  'ag_help_2intro': {
    'ko': '점수가 낮은 사람이 먼저 코트에 들어가요. 확정한 라운드의 누적 기록과 이번 라운드 안의 기록을 합쳐서 봐요.',
    'en':
        'Lower score goes on court first. It combines the confirmed cumulative record with what\'s happened within this round.',
  },
  'ag_help_2a': {'ko': '출전 횟수가 적을수록 먼저.', 'en': 'Fewer games played → sooner.'},
  'ag_help_2b': {
    'ko': '대기 횟수가 많을수록 먼저. 특히 연달아 두 번 쉬지 않게 큰 벌점을 걸어요.',
    'en':
        'More times benched → sooner, and being benched twice in a row is penalized hard.',
  },
  'ag_help_2c': {
    'ko':
        '가능 포지션이 적은 사람이 먼저. 세터만 되는 사람은 세터 자리에 우선 들어가요. 그래야 그 사람이 대기로 밀리지 않아요.',
    'en':
        'Fewer eligible positions → sooner. Setter-only players get the setter slot first, so they don\'t get benched.',
  },
  'ag_help_2d': {
    'ko':
        '같은 포지션 반복은 피해요. 단, 포지션을 고를 수 있는 사람에게만 적용되고, 한 포지션만 되는 사람은 반복해도 벌점이 없어요.',
    'en':
        'Repeating the same position is avoided — but only for players who can pick; single-position players get no penalty for repeating.',
  },
  'ag_help_2e': {
    'ko': '운동 종료 전에 가는 사람은 있는 동안 거의 무조건 출전해요. 어차피 뒤 경기를 못 뛰기 때문이에요.',
    'en':
        'Players leaving before session end play almost every game while present, since they can\'t play later ones.',
  },
  'ag_help_h3': {'ko': '자주 묻는 것', 'en': 'FAQ'},
  'ag_help_q1': {
    'ko': '세터 전용이 있으면 다른 사람 S를 꺼야 해요?',
    'en': 'If there\'s a setter-only player, should I turn off S for others?',
  },
  'ag_help_a1': {
    'ko':
        '아니요. 세터 전용이 있으면 어차피 그 사람이 세터 자리를 먼저 가져가요. S를 켜둬야 세터 전용이 대기 중이거나 일찍 갔을 때 대신 들어갈 수 있어요.',
    'en':
        'No. A setter-only player takes the setter slot first anyway. Keep S on so someone can cover when that setter is benched or has left.',
  },
  'ag_help_q2': {
    'ko': 'A · B · C 모드가 안 만들어져요.',
    'en': 'A · B · C mode won\'t build.',
  },
  'ag_help_a2': {
    'ko':
        '참석 인원이 팀 인원의 2배~3배 사이여야 해요 (6인 팀 12~18명, 7인 팀 14~21명). 인원이 맞는데도 안 되면 특정 포지션 전용 인원이 코트 자리보다 많은 경우예요. 에러 안내를 확인하거나 자유 편성으로 바꿔 보세요.',
    'en':
        'Attendance must be 2×–3× a team size (6-team: 12–18, 7-team: 14–21). If the count fits but it still fails, some position-only group outnumbers the court slots. Check the error note or switch to Free draft.',
  },
  'ag_help_q3': {'ko': 'C 코어가 없다고 나와요.', 'en': 'It says there\'s no C core.'},
  'ag_help_a3': {
    'ko':
        '참석이 팀 인원의 정확히 2배일 때예요. C는 전원 차출이라 세 경기 모두 같은 두 팀이 붙어요. 상대를 섞으려면 자유 편성을 쓰세요.',
    'en':
        'That\'s when attendance is exactly 2× a team size. C is fully borrowed, so all three games pit the same two teams. Use Free draft to mix opponents.',
  },
  'ag_help_q4': {'ko': '확정은 언제 눌러요?', 'en': 'When do I hit Confirm?'},
  'ag_help_a4': {
    'ko':
        '그 라운드를 실제로 뛰고 나서요. 확정해야 기록에 쌓이고 다음 라운드 공정성에 반영돼요. 마음에 안 들면 확정 전에 다시 뽑으면 돼요.',
    'en':
        'After actually playing that round. Confirming logs it and feeds next round\'s fairness. Not happy? Redraw before confirming.',
  },

  // ── 데이터 신뢰도 + 신고 (웹 data-trust.js / guidelines.html 2-3 · 3-1) ──
  'dt_last_verified': {'ko': '최종 확인', 'en': 'Last checked'},
  'dt_needs_check': {'ko': '확인 필요', 'en': 'needs check'},
  'dt_unknown': {'ko': '최종 확인일 정보 없음', 'en': 'Last checked: unknown'},
  'dt_report': {'ko': '정보가 틀렸어요', 'en': 'Report incorrect info'},
  'rp_title': {'ko': '잘못된 정보 신고', 'en': 'Report incorrect info'},
  'rp_intro': {
    'ko': '확인하고 영업일 7일 안에 반영해요. 신고한 사람의 정보는 남기지 않아요.',
    'en':
        'We review reports within 7 business days. No personal information is stored.',
  },
  'rp_reason_label': {'ko': '어떤 문제인가요? (필수)', 'en': "What's wrong? (required)"},
  'rp_wrong_info': {'ko': '정보가 틀림', 'en': 'Incorrect info'},
  'rp_closed': {'ko': '운영 종료/해체', 'en': 'No longer active'},
  'rp_duplicate': {'ko': '중복 등록', 'en': 'Duplicate'},
  'rp_inappropriate': {'ko': '부적절한 내용', 'en': 'Inappropriate'},
  'rp_other': {'ko': '기타', 'en': 'Other'},
  'rp_detail_label': {'ko': '자세히 (선택)', 'en': 'Details (optional)'},
  'rp_detail_ph': {
    'ko': '예: 연습 요일이 화·목으로 바뀌었어요',
    'en': 'e.g. Practice days changed to Tue/Thu',
  },
  'rp_submit': {'ko': '신고 보내기', 'en': 'Send report'},
  'rp_sending': {'ko': '보내는 중…', 'en': 'Sending…'},
  'rp_need_reason': {'ko': '어떤 문제인지 골라 주세요', 'en': "Choose what's wrong."},
  'rp_done': {
    'ko': '신고를 받았어요. 확인하고 반영할게요. 고마워요!',
    'en': "Report received. Thanks — we'll review it.",
  },
  'rp_fail': {
    'ko': '신고를 보내지 못했어요. 잠시 후 다시 해 주세요.',
    'en': "Couldn't send the report. Please try again in a moment.",
  },

  // 포장하기 도시락 칸 라벨 — 웹 js/my-card.js 의 mc_* 와 같은 문구.
  // 화면 UI 의 '밥을 담아 주세요🍚' 에서 명령형만 뺐다(공유물은 남에게 가는 이미지다).
  'mc_rice': {'ko': '밥 🍚', 'en': 'Rice 🍚'},
  'mc_soup': {'ko': '국 🥘', 'en': 'Soup 🥘'},
  'mc_side1': {'ko': '반찬1 🍳', 'en': 'Side 1 🍳'},
  'mc_side2': {'ko': '반찬2 🥗', 'en': 'Side 2 🥗'},
  'mc_side3': {'ko': '반찬3 🥢', 'en': 'Side 3 🥢'},

  // ── 팀 관리자 권한 (웹 i18n.js ad_* 와 같은 문구) ──
  'ad_title': {'ko': '팀 관리자 신청', 'en': 'Request team admin'},
  'ad_desc': {
    'ko':
        '관리자가 되면 이 팀 정보를 직접 고칠 수 있어요.\n본인이 이 팀 사람이라는 걸 알 수 있는 사진을 올려 주세요.\n\n예) 팀 단톡방 화면 · 팀 유니폼 입고 찍은 사진 · 팀 인스타 계정 관리 화면\n※ 다른 분 이름이나 연락처는 가리고 올려 주세요.',
    'en':
        'Admins can edit this team\'s information directly.\nUpload a photo showing that you belong to this team.\n\ne.g. your team group chat, you in the team uniform, the team\'s Instagram account screen\n※ Please mask other people\'s names and contact details.',
  },
  'ad_submit': {'ko': '관리자 신청하기', 'en': 'Submit request'},
  'ad_apply_btn': {'ko': '🙋 이 팀 관리자 신청', 'en': '🙋 Request team admin'},
  'ad_login_required': {
    'ko': '관리자 신청은 로그인하면 할 수 있어요',
    'en': 'Log in to request admin access.',
  },
  'ad_done': {
    'ko': '관리자 신청을 받았어요.\n확인되면 팀 정보를 고칠 수 있어요.',
    'en': "Request received.\nYou can edit the team once it's approved.",
  },
  'ad_error': {
    'ko': '관리자 신청을 보내지 못했어요. 잠시 후 다시 해 주세요.',
    'en': "Couldn't send the request. Please try again in a moment.",
  },
  'ad_pending': {
    'ko': '⏳ 관리자 신청을 확인하고 있어요',
    'en': '⏳ Your admin request is under review.',
  },
  'ad_rejected': {
    'ko': '❌ 관리자 신청이 받아들여지지 않았어요',
    'en': '❌ Admin request was not accepted',
  },
  'ad_reapply': {'ko': '🔄 다시 신청', 'en': '🔄 Apply again'},
  // 거절 사유 코드(club_admin_requests.reject_reason) → 사람이 읽는 말.
  // 서버가 쓰는 코드는 full · already_admin · not_found · duplicate 뿐이다.
  // 모르는 코드(옛 문서의 error 등)나 사유 없는 수동 거절은 사유 줄을 아예 안 보인다.
  'ad_reason_full': {
    'ko': '관리자가 이미 3명이에요',
    'en': 'This team already has 3 admins',
  },
  'ad_reason_already_admin': {
    'ko': '이미 이 팀 관리자예요',
    'en': "You're already an admin of this team",
  },
  'ad_reason_not_found': {
    'ko': '팀 정보를 찾지 못했어요',
    'en': "We couldn't find this team",
  },
  'ad_reason_duplicate': {
    'ko': '같은 신청이 이미 들어가 있어요',
    'en': 'The same request is already in',
  },
  'ad_full': {
    'ko': '이 팀은 관리자가 벌써 3명이에요',
    'en': 'This team already has 3 admins.',
  },
  'ad_count': {'ko': '관리자 {n}/3명', 'en': 'Admins {n}/3'},
  'ad_leave': {'ko': '관리자에서 빠지기', 'en': 'Leave as admin'},
  'ad_leave_confirm': {
    'ko': '이 팀의 관리자에서 빠질까요?\n빠지면 팀 정보를 고칠 수 없어요.',
    'en':
        "Leave as an admin of this team?\nYou won't be able to edit it anymore.",
  },
  'ad_leave_done': {'ko': '관리자에서 빠졌어요', 'en': "You're no longer an admin"},
  'ad_leave_error': {
    'ko': '처리하지 못했어요. 잠시 후 다시 해 주세요.',
    'en': 'Something went wrong. Please try again in a moment.',
  },

  // ── 위치 공개 수준 ──
  'reg_area_only': {
    'ko': '대략적인 위치만 공개',
    'en': 'Show approximate location only',
  },
  'reg_area_only_desc': {
    'ko':
        '지도에 정확한 핀 대신 동네 범위로 표시하고, 주소는 시·군·구까지만 보여요. 체육관 이름과 상세 주소는 저장하지 않아요. 세부 위치를 공개하고 싶지 않은 팀에 권해요.',
    'en':
        'Shows a neighbourhood area instead of an exact pin, and the address only down to the district. The venue name and full address are not stored. Recommended for teams that would rather not share their exact location.',
  },
  'reg_area_label_fail': {
    'ko': '이 주소로는 동네 범위를 만들지 못했어요. 지도에서 위치를 찍어 주세요.',
    'en':
        "Couldn't work out the area from this address. Pick the location on the map.",
  },
  'cd_area_only': {'ko': '대략 위치', 'en': 'Approximate'},
  'cd_area_only_note': {
    'ko': '이 팀은 대략적인 위치만 공개해요. 정확한 장소는 팀에 물어봐 주세요.',
    'en':
        'This team shares only an approximate location. Ask them for the exact venue.',
  },

  // ── 밥친구 (웹 js/i18n.js fr_* 와 같은 문구) ──
  'fr_page_card': {'ko': "내 카드", 'en': "My card"},
  'fr_page_friends': {'ko': "밥친구", 'en': "Bap friends"},
  'fr_title_n': {'ko': "밥친구 {n}", 'en': "Bap friends {n}"},
  'fr_add_btn': {'ko': "+ 추가", 'en': "+ Add"},
  'fr_back': {'ko': "뒤로", 'en': "Back"},
  'fr_loading': {'ko': "불러오는 중…", 'en': "Loading…"},
  'fr_incoming': {'ko': "받은 신청", 'en': "Requests"},
  'fr_outgoing': {'ko': "보낸 신청", 'en': "Sent"},
  'fr_req_sub': {'ko': "밥친구 신청이 왔어요", 'en': "Wants to be bap friends"},
  'fr_accept': {'ko': "수락", 'en': "Accept"},
  'fr_reject': {'ko': "거절", 'en': "Decline"},
  'fr_cancel': {'ko': "취소", 'en': "Cancel"},
  'fr_waiting': {
    'ko': "수락을 기다리는 중 · 7일 뒤 사라져요",
    'en': "Waiting · expires in 7 days",
  },
  'fr_accepted_toast': {
    'ko': "{name}님과 밥친구가 됐어요",
    'en': "You and {name} are bap friends",
  },
  'fr_accepted_short': {'ko': "밥친구가 됐어요", 'en': "You are now bap friends"},
  'fr_sent_toast': {
    'ko': "신청했어요. 상대가 수락하면 밥친구가 돼요",
    'en': "Request sent. You become friends once they accept",
  },
  'fr_empty_title': {'ko': "아직 밥친구가 없어요", 'en': "No bap friends yet"},
  'fr_empty_body': {
    'ko': "초대코드를 주고받으면 서로의 식단표를 볼 수 있어요.",
    'en': "Swap invite codes to see each other’s schedule.",
  },
  'fr_since': {'ko': "{d}부터 밥친구", 'en': "Friends since {d}"},
  'fr_friend': {'ko': "밥친구", 'en': "Bap friend"},
  'fr_unknown': {'ko': "알 수 없는 밥", 'en': "Unknown rice"},
  'fr_badge_aria': {'ko': "받은 밥친구 신청 {n}개", 'en': "{n} friend requests"},
  'fr_add_title': {'ko': "밥친구 추가", 'en': "Add a bap friend"},
  'fr_my_code': {'ko': "내 초대코드", 'en': "My invite code"},
  'fr_copy': {'ko': "복사", 'en': "Copy"},
  'fr_copy_link': {'ko': "초대 링크 복사", 'en': "Copy invite link"},
  'fr_show_qr': {'ko': "QR", 'en': "QR"},
  'fr_qr_aria': {'ko': "내 초대 링크 QR 코드", 'en': "QR code of my invite link"},
  'fr_code_copied': {'ko': "초대코드를 복사했어요", 'en': "Invite code copied"},
  'fr_link_copied': {'ko': "초대 링크를 복사했어요", 'en': "Invite link copied"},
  'fr_regen': {'ko': "새 코드 받기", 'en': "New code"},
  'fr_regen_confirm': {'ko': "바꾸기", 'en': "Replace"},
  'fr_regen_note': {
    'ko': "새 코드를 받으면 지금 코드는 바로 쓸 수 없어요. 이미 맺은 밥친구는 그대로예요.",
    'en': "Your current code stops working right away. Existing friends stay.",
  },
  'fr_regen_done': {'ko': "새 초대코드를 받았어요", 'en': "New invite code ready"},
  'fr_enter_divider': {'ko': "친구 코드가 있다면", 'en': "Have a friend’s code?"},
  'fr_code_ph': {'ko': "친구 초대코드 6자리", 'en': "Friend’s 6-character code"},
  'fr_find': {'ko': "찾기", 'en': "Find"},
  'fr_request': {'ko': "신청", 'en': "Request"},
  'fr_accept_note': {
    'ko': "코드를 넣어도 바로 친구가 되지 않아요. 상대가 수락해야 서로의 식단표가 보여요.",
    'en':
        "Entering a code only sends a request. Schedules open after they accept.",
  },
  'fr_lk_loading': {'ko': "찾는 중…", 'en': "Looking up…"},
  'fr_lk_invalid': {
    'ko': "초대코드는 영문·숫자 6자리예요.",
    'en': "Invite codes are 6 letters and numbers.",
  },
  'fr_lk_not_found': {
    'ko': "없는 코드예요. 친구가 새 코드를 받았는지 확인해 주세요.",
    'en': "No such code. Ask your friend if they got a new one.",
  },
  'fr_lk_self': {'ko': "내 코드예요.", 'en': "That’s your own code."},
  'fr_lk_ok': {'ko': "밥친구 신청할까요?", 'en': "Send a friend request?"},
  'fr_lk_friend': {'ko': "이미 밥친구예요", 'en': "Already friends"},
  'fr_lk_sent': {'ko': "신청했어요 · 수락을 기다리는 중", 'en': "Request sent · waiting"},
  'fr_lk_received': {
    'ko': "나에게 먼저 신청했어요",
    'en': "They already sent you a request",
  },
  'fr_share_title': {
    'ko': '밥친구에게 보일 팀을 골라 주세요',
    'en': "Choose teams your bap friends can see",
  },
  'fr_share_body': {
    'ko': "체크한 팀과 그 운동 시간이 모든 밥친구에게 보여요. 나중에 도시락 편집의 눈 버튼으로 바꿀 수 있어요.",
    'en':
        "Checked teams and their times are visible to all bap friends. Change later with the eye button in lunchbox edit.",
  },
  'fr_share_none': {
    'ko': "도시락에 담은 팀이 아직 없어요.",
    'en': "No teams in your lunchbox yet.",
  },
  'fr_share_ok': {'ko': "이대로 보이기", 'en': "Share these"},
  'fr_share_done': {
    'ko': "밥친구에게 식단표를 보여줘요",
    'en': "Your schedule is now visible to bap friends",
  },
  'fr_vis_title': {
    'ko': "밥친구에게 내 식단표 보이기",
    'en': "Show my schedule to bap friends",
  },
  'fr_vis_on': {
    'ko': "켜짐 · 숨길 팀은 도시락 편집에서 눈 버튼으로",
    'en': "On · hide teams with the eye in lunchbox edit",
  },
  'fr_vis_off': {
    'ko': "꺼짐 · 밥친구에게는 네임카드만 보여요",
    'en': "Off · friends only see your name card",
  },
  'fr_lb_changed': {'ko': "도시락이 바뀌었어요", 'en': "Lunchbox updated"},
  'fr_lb_title': {'ko': "도시락", 'en': "Lunchbox"},
  'fr_lb_empty': {'ko': "보여주는 팀이 없어요", 'en': "No teams shared"},
  'fr_lb_none': {
    'ko': "아직 식단표를 공개하지 않았어요.",
    'en': "Hasn’t shared a schedule yet.",
  },
  'fr_lb_hidden': {'ko': "식단표를 숨겨 두었어요.", 'en': "Schedule is hidden."},
  'fr_tt_title': {'ko': "식단표 겹쳐 보기", 'en': "Schedules side by side"},
  'fr_tt_me': {'ko': "나", 'en': "Me"},
  'fr_tt_friend': {'ko': "밥친구", 'en': "Friend"},
  'fr_tt_empty': {'ko': "보여줄 운동 시간이 없어요.", 'en': "No workout times to show."},
  'fr_tt_meal': {'ko': "합석", 'en': "Both"},
  'fr_tt_meal_legend': {'ko': "합석", 'en': "Together"},
  'fr_meal_title': {'ko': "이번 주 합석", 'en': "Eating together this week"},
  'fr_meal_tier': {
    'ko': "{tier} · 같은 팀 {n}개",
    'en': "{tier} · shared teams: {n}",
  },
  'fr_meal_zero': {
    'ko': "같은 팀에서 같은 시간에 운동하면 합석이에요.",
    'en': "Same team, same time = eating together.",
  },
  'fr_meal_hint': {
    'ko': "같은 팀 · 같은 시간에 운동하는 밥친구",
    'en': "Friends on the same team at the same time",
  },
  'fr_err_daily': {
    'ko': '신청은 하루 30건까지예요. 내일 다시 해 주세요.',
    'en': "Up to 30 requests a day. Try again tomorrow.",
  },
  'fr_meal_fab': {
    'ko': "이번 주 합석하는 밥친구가 있어요",
    'en': "You play with bap friends this week",
  },
  'fr_warm_0': {'ko': "", 'en': ""},
  'fr_warm_1': {'ko': "한 숟갈", 'en': "A spoonful"},
  'fr_warm_2': {'ko': "한 그릇", 'en': "A bowlful"},
  'fr_warm_3': {'ko': "한솥밥", 'en': "Same pot"},
  'lb_eye_on': {
    'ko': "밥친구에게 보임 (누르면 숨기기)",
    'en': "Visible to friends (tap to hide)",
  },
  'lb_eye_off': {
    'ko': "밥친구에게 숨김 (누르면 보이기)",
    'en': "Hidden from friends (tap to show)",
  },
  'fr_unfriend': {'ko': "밥친구 끊기", 'en': "Remove friend"},
  'fr_unfriend_confirm': {'ko': "끊기", 'en': "Remove"},
  'fr_unfriend_note': {
    'ko': "상대에게 알리지 않아요. 서로의 목록에서 사라져요.",
    'en': "They won’t be notified. You’ll disappear from each other’s list.",
  },
  'fr_unfriended': {'ko': "밥친구를 끊었어요", 'en': "Friend removed"},
  'fr_retry': {'ko': "다시 시도", 'en': "Retry"},
  'fr_err_generic': {
    'ko': '잠시 후 다시 해 주세요.',
    'en': "Please try again in a moment.",
  },
  'fr_err_full': {
    'ko': "밥친구는 100명까지예요.",
    'en': "You can have up to 100 bap friends.",
  },
};
