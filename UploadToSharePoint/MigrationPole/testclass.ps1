class ExampleBook3 {
    [string]   $Name
    [string]   $Author
    [int]      $Pages
    [datetime] $PublishedOn

    ExampleBook3([hashtable]$Info) {
        switch ($Info.Keys) {
            'Name'        { $this.Name        = $Info.Name }
            'Author'      { $this.Author      = $Info.Author }
            'Pages'       { $this.Pages       = $Info.Pages }
            'PublishedOn' { $this.PublishedOn = $Info.PublishedOn }
        }
    }

    ExampleBook3(
        [string]   $Name,
        [string]   $Author,
        [int]      $Pages,
        [datetime] $PublishedOn
    ) {
        $this.Name        = $Name
        $this.Author      = $Author
        $this.Pages       = $Pages
        $this.PublishedOn = $PublishedOn
    }

    ExampleBook3([string]$Name, [string]$Author) {
        $this.Name   = $Name
        $this.Author = $Author
    }
}

[ExampleBook3]::new(@{
    Name        = 'The Hobbit'
    Author      = 'J.R.R. Tolkien'
    Pages       = 310
    PublishedOn = '1937-09-21'
})
[ExampleBook3]::new('The Hobbit', 'J.R.R. Tolkien', 310, '1937-09-21')
[ExampleBook3]::new('The Hobbit', 'J.R.R. Tolkien')
[ExampleBook3]::new()