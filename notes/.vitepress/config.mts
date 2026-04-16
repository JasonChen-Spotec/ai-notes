import { defineConfig } from 'vitepress'

export default defineConfig({
  title: '知识库',
  description: 'AI 对话知识归档',
  lang: 'zh-CN',
  base: '/ai-notes/',

  themeConfig: {
    nav: [
      { text: '首页', link: '/' },
      { text: 'AI', link: '/ai/' },
      { text: 'Programming', link: '/programming/' },
      { text: 'Security', link: '/security/' },
    ],

    sidebar: {
      '/programming/': [
        {
          text: 'Programming',
          items: [
            { text: 'Ubuntu dnsmasq 内网 DNS', link: '/programming/dnsmasq-internal-dns' },
            { text: '华为路由器 MQC 策略路由', link: '/programming/huawei-vrp-policy-route' },
            { text: 'Nginx 指定 API 不记录日志', link: '/programming/nginx-disable-log-for-specific-api' },
          ]
        }
      ],
      '/ai/': [
        {
          text: 'AI',
          items: []
        }
      ],
      '/security/': [
        {
          text: 'Security',
          items: []
        }
      ],
    },

    search: {
      provider: 'local',
    },

    outline: {
      label: '目录',
      level: [2, 3],
    },

    docFooter: {
      prev: '上一篇',
      next: '下一篇',
    },
  },
})
