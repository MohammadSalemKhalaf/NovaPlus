<?php

return [
    'enabled' => (bool) env('FIREBASE_ENABLED', false),

    'default' => env('FIREBASE_PROJECT', 'app'),

    'projects' => [
        'app' => [
            'credentials' => env('FIREBASE_CREDENTIALS', env('GOOGLE_APPLICATION_CREDENTIALS')),

            'database' => [
                'url' => env('FIREBASE_DATABASE_URL'),
            ],

            'cache_store' => env('FIREBASE_CACHE_STORE', 'file'),
        ],
    ],
];
